# Lockscreen Swipe Bouncer Reliability Fix

## 1. Issue Description

When the device is locked and awakened via the Power button, swiping up from the lockscreen to bring up the PIN/pattern keypad (Keyguard Primary Bouncer) results in an immediate glitch:
- The numeric PIN keypad flashes into view for approximately 200–300 ms.
- It abruptly collapses back down to the lockscreen, requiring the user to swipe again.
- Repeated swipes may fail intermittently or succeed only on erratic gestures.

---

## 2. Root Cause Analysis

Diagnostic logcat tracing on crDroid 10 (Android 14) during the swipe up revealed the exact event sequence:

```text
KeyguardTransitionRepository: STARTED transition: TransitionStep(from=LOCKSCREEN, to=PRIMARY_BOUNCER, value=0.0)
FalsingManager: {context=ProximityClassifier reason={percentInProximity=1.000000, threshold=0.100000}}
FalsingManager: {belief=0.375517 confidence=1.0}
KeyguardTransitionRepository: CANCELED transition: TransitionStep(from=LOCKSCREEN, to=PRIMARY_BOUNCER, value=0.0): CANCELED
KeyguardTransitionRepository: STARTED transition: TransitionStep(from=PRIMARY_BOUNCER, to=LOCKSCREEN, value=0.0)
KeyguardTransitionRepository: FINISHED transition: TransitionStep(from=PRIMARY_BOUNCER, to=LOCKSCREEN, value=1.0)
```

### The Mechanism:
1. **AOSP SystemUI `FalsingManager` / `ProximityClassifier`:**  
   During a lockscreen unlock gesture, SystemUI invokes `FalsingManager` to verify if the swipe was an accidental touch inside a pocket.
2. **Proximity Sampling:**  
   `com.android.systemui.util.sensors.ThresholdSensorImpl` activates the optical proximity sensor (`ams AG tmd2725`) to evaluate proximity coverage during the gesture.
3. **Hardware Optical Crosstalk:**  
   Inspection of TMD2725 calibration in `/mnt/vendor/persist/sensors/registry/registry/tmd2725_platform.prox.fac_cal` showed:
   - `near_threshold: 126.0`
   - `far_threshold: 55.0`  
   Under protective glass (screen protectors) or aging optical diodes, baseline internal reflections keep the raw ADC reflection count higher than `55.0`. As a result, the proximity sensor permanently reports `NEAR` (`0.00 cm`).
4. **Gesture Cancellation:**  
   Because the proximity sensor reported `NEAR` for 100% of the gesture duration (`percentInProximity=1.000000 >= threshold=0.100000`), `ProximityClassifier` flagged the swipe as an in-pocket false gesture. SystemUI immediately aborted the bouncer transition and snapped the keypad back to the lockscreen.

---

## 3. The Solution

The module provides `scripts/toggle_keyguard_swipe.sh` which sets:

```sh
device_config put systemui brightline_falsing_proximity_percent_covered_threshold 2.0
device_config set_sync_disabled_for_tests persistent
```

### Why this works:
- SystemUI's `ProximityClassifier` reads `brightline_falsing_proximity_percent_covered_threshold` dynamically via `DeviceConfigProxy`.
- Setting the threshold to `2.0` (200%) makes it mathematically impossible for the proximity ratio (bounded between `0.0` and `1.0`) to trigger a false rejection.
- Legitimate swipe-up gestures transition cleanly and smoothly to the PIN/pattern bouncer with 100% reliability.
- When toggled off, `device_config delete` restores the default stock sensitivity.
