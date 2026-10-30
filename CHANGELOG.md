# Changelog

## v2.9
- **Lockscreen Swipe-Up Bouncer Reliability Fix**: Resolved annoying Keyguard PIN/Pattern bouncer collapse bug where keypad flashed for 200–300 ms and snapped back down to lockscreen.
- **Root Cause Neutralization**: Neutralized AOSP `FalsingManager` / `ProximityClassifier` false rejection caused by optical proximity sensor (`ams AG tmd2725`) crosstalk / threshold miscalibration via `brightline_falsing_proximity_percent_covered_threshold`.
- **Hardware Proximity Threshold Audit**: Audited TMD2725 hardware calibration in persist (`tmd2725_platform.prox.fac_cal`), proving optical crosstalk under protective glass caused proximity state to remain stuck at NEAR (`0.00 cm`).
- **Interactive WebUI Toggle**: Added dedicated Card 7 in WebUI dashboard with instant live toggling and status tracking.
- **Test Suite Expansion**: Added test cases for keyguard swipe bouncer controller, bringing comprehensive test suite to 60/60 passed (100%).

## v2.8
- **Standalone Dialer Battery Optimizer**: Guarded optimization disabling duplicate AOSP dialer (`com.android.dialer`) background wakelocks and sync loops when Google Phone or another dialer is set as default.
- **Telephony Safety Guard**: Multi-layered pre-flight check guarantees `com.android.dialer` is never touched if it is the only dialer or the active default dialer, preventing emergency or normal call failures.
- **Interactive WebUI Toggle**: Added live bidirectional toggle card in WebUI for real-time control with 0ms optimistic updates.

## v2.7
- **Phantom Enter Elimination**: Disabled `DPAD_CENTER` keycodes in `uinput-goodix.kl` to prevent accidental folder/app launching when touching the fingerprint sensor on unlocked screen.
- **Biometric Cleanliness**: Ensured Goodix sensor inputs are reserved exclusively for authentication services without interfering with launcher navigation.

## v2.6
- **Zero-Reboot Hot-Reload Engine**: Live module synchronization into `/data/adb/modules/` during Magisk installation.
- **On-the-Fly Tweaks Apply**: Instant background application of system tuning without requiring device reboot.
- **State Preservation**: Persists active user kinematics/scroll settings across seamless upgrades.

## v2.5
- **Magisk Auto-Update Engine**: Native one-click updates directly inside Magisk Modules tab via `updateJson`.
- **Packaging Refinement**: Pure 27 KB module footprint excluding documentation from installation zip.

## v2.4
- **60Hz Kinematic Scroll Engine**: Unified Core Unrestrict (Pixel 8-core SystemUI & RenderThread affinity), 60Hz VSYNC decay damping (60ms/33.3ms), 342MHz GPU floor, and kinetic touch boost (350ms iOS / 250ms Android).
- **Interactive WebUI**: Instant optimistic UI switching (0ms delay) with animated circular progress indicator.
- **Fast Shell Architecture**: Shell execution optimized from 3.2s down to 0.4s (8x speedup).
- **Automated Self-Diagnostics**: 52 automated tests with 100% pass rate.

## v2.2
- **Bidirectional Live Toggling**: Toggle any feature on or off in real time with exact reverse-order stock restoration.

## v2.1
- **Standalone WebUI**: KsuWebUI and MMRL compatibility fixes and automated test suite.

## v2.0
- Initial all-in-one release: Goodix screen-off wake fix, statsd battery drain fix, VoIP AEC fallback, Audio HAL recovery daemon.
