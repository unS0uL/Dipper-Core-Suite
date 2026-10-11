# Audio Ringer Mode Watchdog & Sound Routing Recovery

## Target Platform
- **Device:** Xiaomi Mi 8 (`dipper`)
- **Audio Stack:** Qualcomm Audio HAL (`android.hardware.audio.service`) & AudioFlinger
- **Trigger Scenario:** Rapid switching between Sound, Vibrate, and Silent ringer presets

---

## 1. Problem Description
When switching ringer presets using the volume slider or quick settings tile (Sound -> Vibrate -> Silent -> Sound), media, notification, and ringtone audio occasionally vanishes completely. Even when set back to maximum volume in "Sound" mode, no audio plays through the loudspeaker until the phone is completely rebooted.

---

## 2. Technical Investigation & Root Cause

### A. Android Audio HAL Muting State Inconsistency
During rapid ringer mode changes, the framework sends state changes down through `AudioService` -> `AudioPolicyService` -> `AudioFlinger` -> Qualcomm Audio HAL:
1. When transitioning to Vibrate/Silent, `AudioFlinger` applies a muting mask to the primary hardware output stream (e.g. stream flags `0x1a6`).
2. Simultaneously, volume ducking and device selection commands are sent across the HIDL/AIDL boundary to `android.hardware.audio.service`.
3. Under rapid preset changes, a race condition occurs in Qualcomm's legacy audio HAL thread pool: the un-mute command is received while a device switch state (`AUDIO_DEVICE_OUT_SPEAKER` -> `AUDIO_DEVICE_OUT_EARPIECE`) is still in progress.
4. The HAL completes the route transition but misses the un-mute transaction, leaving the internal DAC gain registers at zero or leaving the primary output routed to the earpiece/receiver rather than the loudspeaker.

---

## 3. The Solution

1. **Automated Background Watchdog (`audio_watchdog.sh`)**:
   - A lightweight shell daemon runs at `low` priority monitoring the system setting `mode_ringer` via `settings get global mode_ringer`.
   - When a transition back to mode `2` (`RINGER_MODE_NORMAL` / Sound) is detected:
     - The watchdog verifies stream output routing and volume state.
     - If the HAL is unresponsive or muted, it issues an audio subsystem reset by restarting `android.hardware.audio.service`.
     - `init` respawns the audio HAL in less than 500 ms, completely clearing stale muting masks and DAC registers.
2. **Instant Manual Recovery via WebUI**:
   - The WebUI exposes two instant recovery triggers:
     - **`Restart Audio HAL`**: Directly restarts the audio service without dropping active network or app states.
     - **`Reset Speaker Routing`**: Issues an explicit `media volume` and routing broadcast to force sound back to the loudspeaker.
