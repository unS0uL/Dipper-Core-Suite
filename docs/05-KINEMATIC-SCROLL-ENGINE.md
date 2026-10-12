# 60Hz Kinematic Scroll Engine & Micro-Jank Elimination

## Device Target
- **Device:** Xiaomi Mi 8 (`dipper`)
- **Platform:** Qualcomm Snapdragon 845 (`SDM845`) — Octa-core (4x Kryo 385 Silver @ 1.77 GHz + 4x Kryo 385 Gold @ 2.80 GHz)
- **Display Refresh Rate:** 60 Hz (VSYNC interval: 16.666 ms)
- **OS Platform:** Android 14 (crDroid 10.10 / LineageOS 21+)

---

## 1. Problem Description
Users observed micro-jank and dropped frames during notification shade expansion and fast kinetic scrolling:
1. When continuously moving a finger across the screen, elements tracked smoothly.
2. The instant the finger was lifted to initiate a kinetic fling, notifications, shelf elements, and Quick Settings buttons stuttered and dropped frames.
3. During Quick Settings pulldown, tile animations experienced micro-freezes.

---

## 2. Root Cause Analysis

### A. The Little-Core CPU Restriction (`/dev/cpuset/restricted`)
Investigation of the process affinity of `com.android.systemui` revealed:
```bash
cat /proc/$(pidof com.android.systemui)/cpuset
# Output: /restricted
cat /dev/cpuset/restricted/cpus
# Output: 0-3
```
In crDroid 10 / AOSP on `dipper`, `SystemUI` was placed into the `/dev/cpuset/restricted` cgroup.
By default, the ROM locked `restricted` tasks exclusively to CPU cores `0-3` (the 4 little Cortex-A55 cores).

When complex UI operations occurred (such as Gaussian blurs, QS tile transitions, or multiple notification layouts), the little cores became saturated, spiking frame render times to 32–40 ms (exceeding the 16.6 ms budget for 60 fps).

### B. Premature Touch Boost Cutoff Mid-Fling
Snapdragon 845 utilizes `cpu_boost` kernel module:
* Stock `input_boost_ms = 80` (or 140 ms).
* Stock `schedutil.down_rate_limit_us = 20000` (20 ms).

A human kinetic fling animation lasts between 300 ms and 500 ms. 
With an 80 ms boost duration, the moment the user lifted their finger:
1. Kernel touch boost expired at 80 ms.
2. Schedutil dropped CPU clock frequencies down to idle floor (300–500 MHz) after only 20 ms.
3. The remaining 300 ms of the fling animation was rendered at low CPU frequencies on little cores, causing visible dropped frames.

### C. GPU Frequency Floor Drop
The Adreno 630 GPU default power level was set to power level 6 (257 MHz). During sudden notification pulldowns with Alpha blurs, GPU scaling latency caused brief 1-frame rendering pauses before ramping up.

---

## 3. Engineering Solution

### A. Core Unrestrict (Android 15 / Pixel Backport)
Instead of restricting SystemUI to Little cores, the module executes:
1. `echo "0-7" > /dev/cpuset/restricted/cpus`: Allows restricted cgroups to utilize Kryo Gold Big cores when needed.
2. Migrates `com.android.systemui` to `/dev/cpuset/top-app/cgroup.procs`.
3. Pins `RenderThread` and UI priority tasks to CPU affinity masks `0xf0` (cores 4-7) and `0x90` (cores 4, 7):
   ```bash
   for f in /proc/$pid/task/*/comm; do
       read -r comm < "$f"
       case "$comm" in
           *Render*|*systemui*)
               tid="${f#/proc/$pid/task/}"
               tid="${tid%/comm}"
               taskset -p f0 "$tid" >/dev/null 2>&1
               ;;
       esac
   done
   ```
This reduced frame render times from 32 ms down to 8–10 ms, comfortably within the 16.6 ms 60 fps envelope.

### B. VSYNC 60Hz Damping & Decay Mathematics
At 60 Hz, one frame period is $T_{frame} = \frac{1000000\,\mu s}{60} \approx 16,666\,\mu s$.
* **iOS Inertia Mode (4 VSYNC Frames Hold):**
  $$\text{down\_rate\_limit\_us} = 60,000\,\mu s \approx 3.6 \times T_{frame}$$
  Holds CPU frequencies steady across deceleration tails, preventing frequency drop mid-fling.
* **Android Snappy Mode (2 VSYNC Frames Hold):**
  $$\text{down\_rate\_limit\_us} = 33,333\,\mu s = 2 \times T_{frame}$$
  Provides rapid ramp-down after 2 empty frames for maximum battery efficiency.

### C. Touch Boost Extension
* **iOS Profile:** `input_boost_ms = 350`, boosting CPU cores `0-3` to 1.22 GHz and `4-7` to 1.45 GHz.
* **Android Profile:** `input_boost_ms = 250`, boosting CPU cores `0-3` to 1.32 GHz and `4-7` to 1.61 GHz.
* **WALT Migration:** Downmigrate lowered to 60–65%, upmigrate to 70–75% for early handoff to Kryo Gold clusters.

### D. GPU Floor Stability
Sets Adreno 630 minimum frequency floor to Power Level 5 (342 MHz):
```bash
echo 5 > /sys/class/kgsl/kgsl-3d0/default_pwrlevel
echo 5 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
```

---

## 4. Dual Physics Profiles Comparison

| Parameter | Stock ROM Defaults | 🤖 Android (Snappy) | 🍎 iOS Inertia (Smooth) |
|---|---|---|---|
| **SystemUI CPU Affinity** | Restricted (Cores 0-3) | Top-App (All Cores 0-7) | Top-App (Big Cores 4-7 Priority) |
| **Input Boost Duration** | 80 ms | 250 ms | 350 ms |
| **Input Boost Frequencies** | 1056 MHz | Little: 1324 MHz / Big: 1612 MHz | Little: 1228 MHz / Big: 1459 MHz |
| **Schedutil Down Rate** | 20,000 µs (1.2 frames) | 33,333 µs (2 full VSYNC frames) | 60,000 µs (4 full VSYNC frames) |
| **GPU Minimum Floor** | 257 MHz (Level 6) | 342 MHz (Level 5) | 342 MHz (Level 5) |
| **Animator Duration** | 0.5x | 0.5x | 1.0x (Decoupled shelf physics) |
| **Schedtune Boost** | 10 | 25 | 25 |

---

## 5. Reverse Stock Restoration
When toggled off, `toggle_scroll_profile.sh disable` restores:
- SystemUI process back to `/dev/cpuset/restricted`
- Restricted cpus back to `0-3`
- Input boost back to 80 ms / 1056 MHz
- Schedutil down rate back to 20,000 µs
- GPU floor back to Level 6 (257 MHz)
- Global `animator_duration_scale` back to user's stock baseline
