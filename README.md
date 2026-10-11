# Dipper Core Suite
**Author:** unS0uL  
**Version:** 2.0  
**Target Device:** Xiaomi Mi 8 (`dipper`)  
**OS Platform:** Android 14 / crDroid 10 / LineageOS 21-22  

---

## Overview
`Dipper Core Suite` is an all-in-one low-level system enhancement module for Xiaomi Mi 8 (`dipper`). It unifies critical hardware fixes and battery optimizations into a single, clean module with a live WebUI dashboard (compatible with KsuWebUI and MMRL WebUI).

---

## Included Components & Root Cause Analysis

### 1. Screen-Off Fingerprint Wake Fix (Goodix Milan HV)
- **The Problem:**
  When the screen was locked and turned off for more than 5 seconds, touching the rear Goodix fingerprint scanner failed to wake or unlock the device.
- **Root Cause:**
  When the display panel enters deep sleep (`DRM_BLANK_POWERDOWN`), the Goodix HAL issues command `1018 (CMD_SCREEN_OFF)`. On the next touch, TrustZone (`gfdip`) threw timing error `1094 (GF_ERROR_TOO_FAST)`, which translated to Android `onAcquired(5)`. The Goodix HAL closed its session without returning a terminal callback (`onError` or `onAuthenticated(false)`), causing Android 14's `BiometricScheduler` to permanently hang in `State: 2 (RUNNING)`.
  Additionally, the stock keylayout `/system/usr/keylayout/uinput-goodix.kl` had the input key lines commented out (`#key 106 DPAD_RIGHT VIRTUAL`), preventing the Linux input subsystem from waking the display upon touch.
- **The Fix:**
  - Injected an active keylayout with `key 106 DPAD_RIGHT WAKE` and `key 353 WAKEUP`.
  - Maintained unmasked hardware IRQ via `proximity_state = 0`.
  - Enables instant wake & unlock with a light touch even from full deep sleep.

---

### 2. Statsd & Daemon CPU Drain Optimization (95% Deep Sleep)
- **The Problem:**
  Device failed to enter hardware suspend / Deep Sleep (0% suspend time) after boot, draining the battery rapidly.
- **Root Cause:**
  crDroid ran `stop statsd` in `/vendor/etc/init/hw/init.target.rc`. In Android 14, system daemons (`org.lineageos.pocketmode`, `co.aospa.sense`, `ifaa`, `soter`, `gamespace`) constantly attempt to write stats socket events. With `statsd` stopped, these daemons fell into an infinite `nanosleep(5ms)` retry loop, consuming ~10% permanent CPU load across all 8 SDM845 cores.
- **The Fix:**
  - Automated restart of `statsd` at boot.
  - Automatically kills and restarts trapped daemons once, breaking the retry loop.
  - CPU returns to natural 95% Deep Sleep ratio.

---

### 3. VoIP AEC Fallback (AML Supported)
- **The Problem:**
  Faulty Qualcomm hardware AEC caused broken acoustics or muting during VoIP calls (WhatsApp, Telegram, etc.).
- **The Fix:**
  Hides the problematic Qualcomm AEC attachment from `VOICE_COMMUNICATION` in `audio_effects.xml` while preserving Qualcomm Noise Suppression (NS). Full compatibility with Audio Modification Library (AML) and Viper4Android.

---

### 4. Automatic Audio Routing & Ringer Watchdog
- **The Problem:**
  Switching volume presets/ringer modes (Sound -> Vibrate -> Silent -> Sound) occasionally caused all audio output to disappear completely until a full device reboot.
- **Root Cause:**
  During rapid transitions, Qualcomm SDM845 audio HAL (`android.hardware.audio.service`) and AudioFlinger could get stuck in an inconsistent muting mask (`0x1a6`) or retain the primary output route on `earpiece` (receiver) rather than falling back to `speaker`.
- **The Fix:**
  - A lightweight background watchdog (`audio_watchdog.sh`) monitors system ringer mode changes (`mode_ringer`).
  - Upon returning to `NORMAL` (Sound mode), the watchdog verifies primary output state and unmutes/restarts the Audio HAL automatically within 1 second if routing is locked up.
  - Manual recovery buttons are also accessible in the WebUI.

---

## WebUI Controls (Without Reboot)
Access via the **Action** button in Magisk or the **KsuWebUI** app:
- **Screen-Off Fingerprint Wake Toggle:** Live bind-mount & HAL reload.
- **Statsd & Battery Optimizer Toggle:** Live daemon cycle control.
- **Restart Audio HAL Button:** Instant 1-second audio server recovery.
- **Reset Speaker Routing Button:** Forces media & ringtone output back to the loudspeaker.
