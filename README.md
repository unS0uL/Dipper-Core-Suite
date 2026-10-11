# Dipper Core Suite
**Author:** unS0uL  
**Version:** 2.1  
**Target Device:** Xiaomi Mi 8 (`dipper`)  
**OS Platform:** Android 14 / crDroid 10 / LineageOS 21-22  
**Root Framework:** Magisk (v26+ / v30+) & KernelSU  

---

## Overview
**Dipper Core Suite** is an all-in-one low-level system enhancement module for Xiaomi Mi 8 (`dipper`). It consolidates critical hardware fixes, audio improvements, and battery optimizations into a single module with an interactive WebUI dashboard (accessible via the Magisk Action button or KsuWebUI).

Every feature can be dynamically enabled or disabled in real time **without rebooting the device**.

---

## Features at a Glance

| Feature | Problem Solved | Mechanism | Live Toggle |
|---|---|---|:---:|
| **Fingerprint Screen-Off Wake** | Rear Goodix scanner fails to wake/unlock when screen is off in hand | Unmasks kernel IRQ 334, locks `proximity_state` to 0, neutralizes buggy `XiaomiPocketMode`, & injects `WAKE` keylayout | ✅ Yes |
| **Statsd Battery Optimizer** | SDM845 fails to enter Deep Sleep (0% suspend time, heavy drain) | Restarts `statsd` & breaks infinite 5ms daemon retry loop | ✅ Yes |
| **VoIP AEC Fallback** | Remote party hears loud echo during VoIP speakerphone calls | Disables broken hardware AEC in `audio_effects.xml`, enabling app AEC3 | ✅ Yes |
| **Audio Ringer Watchdog** | Sound permanently disappears after toggling ringer presets | Background daemon detects transition and auto-restores Audio HAL within 1s | ✅ Yes |

---

## Deep Technical Documentation

For detailed analysis of root causes, kernel/HAL traces, and exact architectural implementations, refer to the documentation:

- 📖 [**Fingerprint Screen-Off Wake & Goodix TA Analysis**](docs/01-FINGERPRINT-WAKE.md)
- 📖 [**Statsd & Daemon 5ms CPU Loop Battery Analysis**](docs/02-BATTERY-OPTIMIZER.md)
- 📖 [**VoIP AEC Fallback & Far-End Echo Elimination**](docs/03-VOIP-AEC-FALLBACK.md)
- 📖 [**Audio Ringer Watchdog & Routing Recovery**](docs/04-AUDIO-RINGER-WATCHDOG.md)

---

## WebUI Controls (Live On-the-Fly)
Access via the **Action** button in the Magisk app or via **KsuWebUI / MMRL**:
- **Screen-Off Fingerprint Wake:** Live bind-mount of `uinput-goodix.kl` & fingerprint HAL reload.
- **VoIP Echo Fix (AEC Fallback):** Live bind-mount of `audio_effects.xml` & audio server reload.
- **Audio Ringer Watchdog & Recovery:** Auto-guard toggle daemon + 1-click **Restart Audio HAL** & **Reset Speaker Routing** buttons.
- **Statsd Battery Optimizer:** Live daemon cycle control.

---

## Installation
1. Download the latest `dipper-core-suite-v2.1.zip` from [Releases](https://github.com/unS0uL/Dipper-Core-Suite/releases).
2. Flash via Magisk or KernelSU.
3. Reboot device once to register services.

---

## Automated Verification & Test Suite
The module includes a comprehensive automated test suite (`tools/test_suite.sh`) verifying all low-level subsystems:
- WebUI accessibility & directory permissions (0755 `/data/adb`)
- Goodix kernel IRQ unmasking & locked read-only state (0444)
- `XiaomiPocketMode` neutralization state
- VoIP hardware AEC absence in active audio configuration
- Audio Watchdog daemon and Audio HAL responsiveness
- Statsd service status, `/dev/socket/statsdw`, and system load average

To run diagnostics manually on the device:
```bash
su -c 'sh /data/adb/modules/dipper_core_suite/tools/test_suite.sh'
```

