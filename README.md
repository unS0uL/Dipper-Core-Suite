# Dipper Core Suite

Low-level hardware, kernel, and audio enhancement suite tailored specifically for **Xiaomi Mi 8 (`dipper`)**.

Consolidates hardware display wake fixes, VoIP acoustic echo cancellation fallback, Audio HAL freeze recovery, deep sleep battery optimization, and a unified 60Hz kinematic scroll engine into a lightweight Magisk module featuring an interactive WebUI dashboard.

---

> [!WARNING]
> **Disclaimer & Safety:**  
> Any system modifications, flashing, and root module usage are performed entirely at your own risk. Neither the author nor contributors take responsibility for damaged hardware, bricked devices, or lost data.  
> As with any root modifications, conflicts with other modules, custom ROM variations, or improper installation can potentially cause bootloops. Always maintain a current backup (TWRP/Nandroid or stock `boot.img`) and know how to boot into Safe Mode or remove modules via recovery if an issue arises.

---

## WebUI Live Dashboard

Every feature can be dynamically toggled on or off in real time **without rebooting the device**. When toggled off, the module restores the **exact stock system state in reverse order**.

<p align="center">
  <img src="https://raw.githubusercontent.com/unS0uL/Dipper-Core-Suite/media/webui_dashboard.png" alt="Dipper Core Suite WebUI" width="420">
</p>

Access the dashboard anytime:
- In **Magisk**: tap the **Action** button next to the module.
- Or launch via **KsuWebUI / MMRL**.

---

## Features

| Feature | Problem Solved | Mechanism | Live Toggle (Reverse Stock) |
|---|---|---|:---:|
| **Fingerprint Screen-Off Wake** | Rear Goodix scanner fails to wake/unlock when screen is off in hand | Unmasks kernel IRQ 334, locks `proximity_state` to 0, neutralizes buggy `XiaomiPocketMode`, & injects `WAKE` keylayout | Yes (Hard IRQ disable on off) |
| **Statsd Battery Optimizer** | SDM845 fails to enter Deep Sleep (0% suspend time, heavy drain) | Restarts `statsd` & breaks infinite 5ms daemon retry loop | Yes |
| **VoIP AEC Fallback** | Remote party hears loud echo during VoIP speakerphone calls | Disables broken hardware AEC in `audio_effects.xml`, enabling clean app AEC3 | Yes (Restores stock XML) |
| **Audio Ringer Watchdog** | Sound permanently disappears after toggling ringer presets | Background daemon detects transition and auto-restores Audio HAL within 1s | Yes |
| **Kinematic Scroll Engine** | Notification shade micro-jank & kinetic fling tail jitter | Unified Core Unrestrict (Pixel 8-core SystemUI/RenderThread affinity), 60Hz VSYNC decay damping (60ms/33.3ms), 342MHz GPU floor, & 350ms fling boost | Yes (iOS Inertia vs Android Snappy) |
| **Standalone Dialer Optimizer** | Duplicate AOSP dialer battery drain when Google Phone is primary | Guardedly mutes dormant AOSP dialer only when an alternative dialer is confirmed default; never breaks single-dialer setups | Yes (Stock Reversion) |
| **Lockscreen Swipe Bouncer Fix** | Keypad flashes for 200–300ms and collapses back down on swipe up | Neutralizes false pocket detection in `FalsingManager` / `ProximityClassifier` caused by optical proximity sensor crosstalk | Yes (Stock Reversion) |

---

## Compatibility

- **Target Device:** Xiaomi Mi 8 (`dipper`, Qualcomm SDM845)
- **Primary Tested ROM:** Android 14 (**crDroid 10**)
- **Other ROMs:** Probably compatible with **LineageOS 21** (the underlying base of crDroid 10) and similar AOSP-based trees for `dipper`, though primarily verified on crDroid 10.
- **Root Solution:** Magisk (v26+ / v30+) or KernelSU.

---

## Installation & Auto-Updates

### Installation
1. Download the latest release zip from [Releases](https://github.com/unS0uL/Dipper-Core-Suite/releases).
2. Flash via Magisk or KernelSU.
3. **Zero-Reboot Hot-Reload:** Updates take effect immediately without requiring a device reboot.

### In-App Auto-Updates via Magisk
The module includes built-in `updateJson` support:
- Whenever a new release is published, an **Update** button appears directly next to Dipper Core Suite in the Magisk Modules tab.
- Tapping **Update** downloads the new release, displays the release changelog, and installs the update with zero-reboot hot-reload.
*(Ensure **Check Updates** is enabled in Magisk settings).*

---

## Deep Technical Documentation

For root cause analyses, kernel traces, and architectural details:
- [Fingerprint Screen-Off Wake & Goodix TA Analysis](docs/01-FINGERPRINT-WAKE.md)
- [Statsd & Daemon 5ms CPU Loop Battery Analysis](docs/02-BATTERY-OPTIMIZER.md)
- [VoIP AEC Fallback & Far-End Echo Elimination](docs/03-VOIP-AEC-FALLBACK.md)
- [Audio Ringer Watchdog & Routing Recovery](docs/04-AUDIO-RINGER-WATCHDOG.md)
- [60Hz Kinematic Scroll Engine & Micro-Jank Elimination](docs/05-KINEMATIC-SCROLL-ENGINE.md)
