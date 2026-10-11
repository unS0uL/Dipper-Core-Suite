# VoIP AEC Fallback & Far-End Echo Elimination

## Target Platform
- **Device:** Xiaomi Mi 8 (`dipper`)
- **Audio Architecture:** Qualcomm SDM845 / WCD9340 Aqstic / Fluence DSP stack
- **Affected Scenarios:** Speakerphone calls in Telegram, WhatsApp, Viber, Messenger, Signal

---

## 1. Problem Description
During VoIP calls on speakerphone, the remote caller hears a severe, disorienting echo of their own voice returning with a 150-300 ms delay. In some conditions, sound from the loudspeaker also cuts out or distorts when both parties speak simultaneously (double-talk distortion).

---

## 2. Technical Investigation & Root Cause

### A. Qualcomm Hardware AEC vs. Android Audio Framework
Android's `audio_effects.xml` defines pre-processing effects attached to input streams of type `voice_communication`:
```xml
<preprocess>
    <stream type="voice_communication">
        <apply effect="aec"/>
        <apply effect="ns"/>
    </stream>
</preprocess>
```
On custom ROMs for `dipper`, the hardware Acoustic Echo Canceler (`aec`, backed by Qualcomm Fluence DSP via `libqcompostprocbundle.so`) is advertised to the Android framework as fully operational.

### B. Route Mismatch & Speakerphone Acoustic Coupling
While Fluence hardware AEC functions correctly during standard earpiece calls (where audio routing goes through ACDB profile 7 and physical sound leakage into the primary bottom microphone is minimal), the speakerphone capture route (`speaker-dmic-endfire`, ACDB 116) fails to calculate accurate phase and delay matrices. 

Because Android advertises hardware AEC support (`AcousticEchoCanceler.isAvailable() == true`), VoIP applications (such as Telegram and WhatsApp) assume the OS/DSP hardware handles echo cancellation and disable their internal software echo cancellation routines (WebRTC AEC3 / Speex). As a result, no effective echo cancellation occurs at either the hardware or software level.

---

## 3. The Solution

1. **Selective Pre-Processing Configuration**:
   Modify `/vendor/etc/audio_effects.xml` to remove the automatic `<apply effect="aec"/>` hook for `voice_communication`, while retaining Qualcomm Noise Suppression (`<apply effect="ns"/>`):
   ```xml
   <preprocess>
       <stream type="voice_communication">
           <apply effect="ns"/>
       </stream>
   </preprocess>
   ```
2. **Graceful Software Fallback**:
   Because Android no longer falsely advertises hardware AEC for `voice_communication`, modern VoIP applications automatically activate their built-in WebRTC AEC3 software cancellation.
3. **Compatibility**:
   - Retains stock Qualcomm Fluence Noise Suppression.
   - Cellular calls are completely unaffected because they route through modem DSP firmware directly.
   - Fully compatible with Audio Modification Library (AML) and Viper4Android.
   - Can be toggled live via WebUI without rebooting.
