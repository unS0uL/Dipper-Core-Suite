# Dipper Core Suite
**Author:** unS0uL  
**Version:** 2.5  
**Target Device:** Xiaomi Mi 8 (`dipper`)  
**OS Platform:** Android 14 (crDroid 10.10) / LineageOS 21-22  
**Root Framework:** Magisk (v26+ / v30+) & KernelSU  

---

## Overview
**Dipper Core Suite** is an all-in-one low-level system enhancement module for Xiaomi Mi 8 (`dipper`). It consolidates critical hardware fixes, audio improvements, battery optimizations, and a unified 60Hz kinematic scroll engine into a single module with an interactive WebUI dashboard (accessible via the Magisk Action button or KsuWebUI).

Every feature can be dynamically enabled or disabled in real time **without rebooting the device**. When toggled off, the module restores the **exact stock system state in reverse order**.

---

## Features at a Glance

| Feature | Problem Solved | Mechanism | Live Toggle (Reverse Stock) |
|---|---|---|:---:|
| **Fingerprint Screen-Off Wake** | Rear Goodix scanner fails to wake/unlock when screen is off in hand | Unmasks kernel IRQ 334, locks `proximity_state` to 0, neutralizes buggy `XiaomiPocketMode`, & injects `WAKE` keylayout | ✅ Yes (Hard IRQ disable on off) |
| **Statsd Battery Optimizer** | SDM845 fails to enter Deep Sleep (0% suspend time, heavy drain) | Restarts `statsd` & breaks infinite 5ms daemon retry loop | ✅ Yes |
| **VoIP AEC Fallback** | Remote party hears loud echo during VoIP speakerphone calls | Disables broken hardware AEC in `audio_effects.xml`, enabling app AEC3 | ✅ Yes (Restores stock XML) |
| **Audio Ringer Watchdog** | Sound permanently disappears after toggling ringer presets | Background daemon detects transition and auto-restores Audio HAL within 1s | ✅ Yes |
| **Kinematic Scroll Engine** | Notification shade micro-jank & kinetic fling tail jitter | Unified Core Unrestrict (Pixel 8-core SystemUI/RenderThread affinity), 60Hz VSYNC decay damping (60ms/33.3ms), 342MHz GPU floor, & 350ms fling boost | ✅ Yes (iOS Inertia vs Android Snappy) |

---

## Deep Technical Documentation

For detailed analysis of root causes, kernel/HAL traces, and exact architectural implementations, refer to the documentation:

- 📖 [**Fingerprint Screen-Off Wake & Goodix TA Analysis**](docs/01-FINGERPRINT-WAKE.md)
- 📖 [**Statsd & Daemon 5ms CPU Loop Battery Analysis**](docs/02-BATTERY-OPTIMIZER.md)
- 📖 [**VoIP AEC Fallback & Far-End Echo Elimination**](docs/03-VOIP-AEC-FALLBACK.md)
- 📖 [**Audio Ringer Watchdog & Routing Recovery**](docs/04-AUDIO-RINGER-WATCHDOG.md)
- 📖 [**60Hz Kinematic Scroll Engine & Micro-Jank Elimination**](docs/05-KINEMATIC-SCROLL-ENGINE.md)

---

## WebUI Controls (Live On-the-Fly)
Access via the **Action** button in the Magisk app or via **KsuWebUI / MMRL**:
- **Screen-Off Fingerprint Wake:** Live bind-mount of `uinput-goodix.kl` & fingerprint HAL reload. Reversible to stock kernel IRQ 334 disable & PocketMode restoration.
- **VoIP Echo Fix (AEC Fallback):** Live bind-mount of `audio_effects.xml` & audio server reload. Reversible to stock AEC audio effects configuration.
- **Audio Ringer Watchdog & Recovery:** Auto-guard toggle daemon + 1-click **Restart Audio HAL** & **Reset Speaker Routing** buttons.
- **Statsd Battery Optimizer:** Live daemon cycle control.
- **Kinematic Scroll & Touch Boost:** Real-time physics profile toggle between **🍎 iOS Inertia (Smooth)** and **🤖 Android (Snappy)** with complete reverse-order stock restoration.

---

## Installation
1. Download the latest `dipper-core-suite-v2.5.zip` from [Releases](https://github.com/unS0uL/Dipper-Core-Suite/releases).
2. Flash via Magisk or KernelSU.
3. Reboot device once to register services.

---

## Automated Verification & Test Suite
The module includes a comprehensive automated test suite (`tools/test_suite.sh`) with 52 automated assertions verifying all low-level subsystems:
- WebUI accessibility & directory permissions (0755 `/data/adb`)
- Goodix kernel IRQ unmasking & locked read-only state (0444)
- `XiaomiPocketMode` neutralization state
- VoIP hardware AEC absence in active audio configuration
- Audio Watchdog daemon and Audio HAL responsiveness
- Statsd service status, `/dev/socket/statsdw`, and system load average
- Kinematic scroll baseline files & profile executables
- **Full bidirectional live toggle tests** (verifying exact reverse-order stock restoration and re-enabling across all 5 features, including iOS/Android profile switching, 60ms/33.3ms down-rates, 350ms/250ms input boost, 0-7 cpuset unrestrict, and 342MHz GPU floor)

To run diagnostics manually on the device:
```bash
su -c 'sh /data/adb/modules/dipper_core_suite/tools/test_suite.sh'
```

