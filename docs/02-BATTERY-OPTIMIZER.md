# Statsd & Daemon 5ms CPU Loop Fix (Restoring Deep Sleep)

## Target Platform
- **Device:** Xiaomi Mi 8 (`dipper`, Qualcomm SDM845)
- **ROM:** crDroid 10.10 (Android 14) / custom ROMs disabling statsd

---

## 1. Problem Description
The device drains battery excessively during standby and fails to enter hardware suspend / Deep Sleep (0% suspend time in `dumpsys batterystats`). Battery drain exceeds 5-8% per hour with the screen off.

---

## 2. Technical Investigation & Root Cause

### A. The Origin of "stop statsd"
In crDroid source code, developers disabled the native statistics collection service (`statsd`) intending to save CPU cycles:
- Commit `f97bd16e2ec244045523342751d5589a4aa031ff`: `statsd: Disable native stats collection service`.
- Marked `disabled` in `/apex/com.android.os.statsd/etc/init.rc`.
- Added `stop statsd` in `/vendor/etc/init/hw/init.target.rc` triggered on `boot_completed`.

### B. Client Side Retry Storm in Android 14
In Android 14, standard system libraries and background vendor daemons (`libstatssocket.so`, `pocketmode`, `co.aospa.sense`, `ifaa`, `soter`, `gamespace`) constantly attempt to report hardware and usage metrics to `/dev/socket/statsdw`.
When `statsd` is stopped:
1. The socket connection fails.
2. In `libstatssocket`, the ring buffer queue does **not** discard the packets. Instead, it enters an internal spin-retry loop:
   ```c
   while (retry_count < MAX_RETRIES) {
       nanosleep(5ms);
       connect_to_statsd();
   }
   ```
3. Multiple background daemons become trapped in this 5ms sleep-and-retry loop simultaneously.
4. Combined, they generate 10-15% constant CPU utilization across all 8 cores, holding active kernel wakelocks and preventing the SDM845 SoC from suspending.

---

## 3. The Solution

1. **Service Restart at Boot**:
   Re-enable and launch `statsd` via `resetprop ctl.start statsd` upon boot completion.
2. **Breaking Daemon Retries**:
   Execute a one-time termination of trapped client daemons (`pkill -f pocketmode`, `pkill -f sense`). `init` immediately respawns them; they establish a valid connection to `statsd` on the first attempt and transition to proper idle sleep.
3. **Verified Result**:
   - Deep sleep suspend ratio restored from **0%** to **95.2%**.
   - Screen-off drain reduced from **~6%/hr** to **~1.2%/hr**.
   - Load average dropped from **4.5+** down to **0.10 - 0.25**.
