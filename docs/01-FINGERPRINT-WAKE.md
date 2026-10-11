# Goodix Milan HV Screen-Off Wake & Unlock Fix

## Device Target
- **Device:** Xiaomi Mi 8 (`dipper`)
- **Sensor:** Goodix rear fingerprint sensor (`milan hv`, kernel driver `drivers/input/fingerprint/gf_spi.c`)
- **Firmware/HAL:** `android.hardware.biometrics.fingerprint@2.1-service` with 32-bit vendor libraries (`libgf_hal.so`, `libgfdip.so`)
- **OS Platform:** Android 14 (crDroid 10.10 / LineageOS 21+)

---

## 1. Problem Description
When the device screen is off and locked for more than 5 seconds (entering full hardware suspend / `DRM_BLANK_POWERDOWN`), touching the rear fingerprint scanner does not turn on the display or unlock the device. The sensor appears completely dead until the physical power button is pressed.

---

## 2. Technical Investigation & Root Cause

### A. Display State Transitions & Goodix Driver Behavior
When the screen turns off, the Android PowerManager invokes display blanking:
1. DRM driver transitions the panel into `DRM_BLANK_POWERDOWN`.
2. Goodix HAL (`fingerprintd`/`android.hardware.biometrics.fingerprint`) receives the screen state change and sends command `1018 (GF_CMD_SCREEN_OFF)` via IOCTL down to `gf_spi`.
3. In `gf_spi.c`, the kernel driver notes `fb_black = 1`.
4. When a finger touches the sensor while `fb_black == 1`, the kernel interrupt handler executes:
   ```c
   if (gf_dev->fb_black) {
       input_report_key(gf_dev->input, KEY_RIGHT, 1);
       input_sync(gf_dev->input);
       input_report_key(gf_dev->input, KEY_RIGHT, 0);
       input_sync(gf_dev->input);
   }
   ```
   The driver expects the Android Linux Input Subsystem to intercept `KEY_RIGHT` (scancode 106) and wake up the display before initiating the SPI biometric scan sequence.

### B. Stock Keylayout Bug
In stock ROM files (`/system/usr/keylayout/uinput-goodix.kl`), the key mappings were commented out:
```text
#key 106   DPAD_RIGHT        VIRTUAL
#key 105   DPAD_LEFT         VIRTUAL
```
Because no key event with the `WAKE` flag was mapped to scancode 106, the Android InputReader dropped the event. The display remained in `DRM_BLANK_POWERDOWN`.

### C. TrustZone Race Condition & BiometricScheduler Lockup
Simultaneously, the Goodix hardware IRQ triggered an SPI read into the proprietary TrustZone applet (`gfdip`):
1. Because the display was still unpowered, TrustZone threw timing error `1094 (GF_ERROR_TOO_FAST)`.
2. In the Goodix HAL, error 1094 maps to Android client acquired message:
   `onAcquired(acquired_info = 5)` (which corresponds to `FINGERPRINT_ACQUIRED_TOO_FAST`).
3. Immediately after emitting `onAcquired(5)`, the vendor HAL exited its capture loop **without** returning a terminal callback (`onError` or `onAuthenticated(false)`).
4. In Android 14's framework `BiometricScheduler`, an authentication request remains open waiting for a completion signal. Because no terminal signal was ever emitted, the scheduler remained stuck in `State: 2 (RUNNING)`.
5. Subsequent finger touches were discarded by the framework because a previous session was theoretically still active.

---

## 3. The Solution

1. **Active Keylayout Injection (`uinput-goodix.kl`)**:
   Map scancode 106 with the explicit `WAKE` policy:
   ```text
   key 106   DPAD_RIGHT        WAKE
   key 353   DPAD_CENTER       WAKE
   ```
   When touched in screen-off state, Android's `InputReader` and `PhoneWindowManager` immediately initiate display wake-up.
2. **Proximity Driver Unmasking**:
   Ensure `proximity_state = 0` so the kernel driver does not suppress input reports under the assumption that the device is in a pocket.
3. **Live Toggling Support**:
   The module supports live unmounting/mounting of `/system/usr/keylayout/uinput-goodix.kl` via `mount -o bind` followed by killing `android.hardware.biometrics.fingerprint@2.1-service`. The service restarts cleanly via `init` in less than 200 ms without requiring a phone reboot.
