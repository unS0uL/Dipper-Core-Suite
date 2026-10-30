# Dipper Core Suite — Technical Documentation Index

Comprehensive low-level technical documentation for **Dipper Core Suite** (Xiaomi Mi 8, `dipper`, Snapdragon 845 / SDM845, Android 14 crDroid 10 / LineageOS 21).

---

## Technical Articles Catalog

| Document | Topic | Key Technologies & Subsystems |
|---|---|---|
| [01. Goodix Milan HV Screen-Off Wake & Unlock Fix](01-FINGERPRINT-WAKE.md) | Hardware IRQ wake, pocket mode bug, keylayout injection | Kernel IRQ 334 (`gf_spi`), `msmgpio-dc 79`, `uinput-goodix.kl`, `XiaomiPocketMode` |
| [02. Statsd & Daemon 5ms CPU Loop Fix](02-BATTERY-OPTIMIZER.md) | Deep Sleep restoration, wakelock elimination | Android 14 `libstatssocket.so`, `/dev/socket/statsdw`, `statsd`, 95% Deep Sleep |
| [03. VoIP AEC Fallback & Far-End Echo Elimination](03-VOIP-AEC-FALLBACK.md) | Speakerphone echo elimination in WhatsApp / Telegram | Qualcomm Fluence DSP, ACDB 116 (`speaker-dmic-endfire`), WebRTC AEC3 fallback |
| [04. Audio Ringer Mode Watchdog & Routing Recovery](04-AUDIO-RINGER-WATCHDOG.md) | Audio loss recovery after ringer mode switching | `AudioFlinger`, Qualcomm Audio HAL (`android.hardware.audio.service`), DAC routing |
| [05. 60Hz Kinematic Scroll Engine 3.0](05-KINEMATIC-SCROLL-ENGINE.md) | Notification shade micro-jank elimination | Cgroups unthrottling (`0-7`), `taskset -p ff`, `renice -n -10`, `soc:qcom,cpubw` 4577 MB/s, PowerHAL lock |
| [06. Standalone Dialer Battery Optimizer](06-STANDALONE-DIALER-OPTIMIZER.md) | Dormant AOSP dialer background battery drain prevention | Android RoleManager (`android.app.role.DIALER`), Telecom pre-flight safety guard |
| [07. Lockscreen Swipe Bouncer Reliability Fix](07-LOCKSCREEN-SWIPE-BOUNCER-FIX.md) | Keyguard swipe collapse / false pocket rejection fix | AOSP SystemUI `FalsingManager`, `ProximityClassifier`, TMD2725 optical crosstalk |

---

## Architectural Principles of Dipper Core Suite

1. **Zero-Reboot Hot-Reload & Reversibility:**  
   Every single optimization can be turned ON or OFF live through the WebUI without rebooting. When disabled, the module restores the exact stock baseline state in reverse order.
2. **Strict Pre-Flight Safety Checks:**  
   No critical system component is modified without positive verification (e.g. dialer checks, PID locks, cgroup path detection).
3. **Hardware-Lock Protection:**  
   System properties and sysfs nodes boosted by the engine are protected against silent background resets from vendor daemons (such as `lineage-libperfmgr` PowerHAL) using explicit permission locks (`chmod 0444`), and unlocked (`chmod 0644`) during reversion.
4. **Automated Verification:**  
   Every release must pass the 75-point automated hardware and software assertion suite (`tools/test_suite.sh`) with 100% pass rate before deployment.
