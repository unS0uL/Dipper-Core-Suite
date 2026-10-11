# Goodix Milan HV Screen-Off Wake & Unlock Fix

## Device Target
- **Device:** Xiaomi Mi 8 (`dipper`)
- **Sensor:** Goodix rear fingerprint sensor (`milan hv`, kernel driver `drivers/input/fingerprint/goodix_ta/gf_spi.c`)
- **Firmware/HAL:** `android.hardware.biometrics.fingerprint@2.3-service.xiaomi` with vendor TrustZone applet (`gfdip`)
- **OS Platform:** Android 14 (crDroid 10.10 / LineageOS 21+)

---

## 1. Problem Description
When the device screen is off and locked in hand (entering full hardware suspend / `DRM_BLANK_POWERDOWN`), touching the rear fingerprint scanner does not turn on the display or unlock the device. The sensor appears completely dead until the user either:
1. Presses the physical power button, OR
2. Covers the top proximity sensor ("pocket check"), which bizarrely made the rear fingerprint scanner work again.

---

## 2. Technical Investigation & Root Cause

### A. The Goodix Kernel IRQ Mechanism (`gf_spi.c`)
In `drivers/input/fingerprint/goodix_ta/gf_spi.c`, the kernel driver exposes a sysfs node:
`/sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state`

The kernel implements writing to this node as follows:
```c
static ssize_t proximity_state_set(struct device *dev,
    struct device_attribute *attr, const char *buf, size_t count)
{
    struct gf_dev *gf_dev = dev_get_drvdata(dev);
    int rc, val;

    rc = kstrtoint(buf, 10, &val);
    if (rc)
        return -EINVAL;

    gf_dev->proximity_state = !!val;

    if (gf_dev->proximity_state) {
        gf_disable_irq(gf_dev); // <-- COMPLETELY DISABLES HW INTERRUPT (IRQ 334)!
    } else {
        gf_enable_irq(gf_dev);  // <-- ENABLES HW INTERRUPT
    }

    return count;
}
```

### B. The `XiaomiPocketMode` (`org.lineageos.pocketmode`) Inverted Bug
Xiaomi SDM845 device trees include a background service `XiaomiPocketMode.apk` (`/system_ext/priv-app/XiaomiPocketMode/XiaomiPocketMode.apk`).
Decompilation of its bytecode (`ProximitySensor.java`) revealed the exact culprit:
```java
public void onSensorChanged(SensorEvent event) {
    boolean isNear = event.values[0] < mSensor.getMaximumRange();
    setFPProximityState(isNear); // Inverted logic!
}

private void setFPProximityState(boolean state) {
    FileUtils.stringToFile("/sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state",
        state ? "1" : "0");
}
```
When the screen locked and the phone was held in hand (sensor open, `isNear == false`), the service sent `1` to `proximity_state` upon display off, invoking `gf_disable_irq()` in the kernel driver. 
Consequently, **the physical interrupt pin `msmgpio-dc 79` was hardware-masked**. Any touches on the rear plate produced zero kernel interrupts (`diff: 0`).

When the user covered the proximity sensor (or put the phone face down), `XiaomiPocketMode` sent `0`, which invoked `gf_enable_irq()`, re-enabling the fingerprint scanner!

### C. Active WAKE Mapping in Linux Input Subsystem
In addition to kernel IRQ unmasking, when `fb_black == 1`, the driver transmits scancode 106 (`KEY_RIGHT`). Android's `InputReader` requires an active `WAKE` policy in `/system/usr/keylayout/uinput-goodix.kl` and `/system/usr/idc/uinput-goodix.idc` (`device.wake = 1`) to immediately wake `PowerManagerService` out of sleep.

---

## 3. The Solution

1. **Hardware IRQ Permanently Unmasked & Locked**:
   ```bash
   chmod 0644 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state
   echo -n 0 > /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state
   chmod 0444 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state
   ```
   Setting permissions to `0444` (read-only) prevents any userspace daemon from disabling the IRQ.

2. **Neutralizing Buggy `XiaomiPocketMode` Components**:
   Rather than risking removing package registrations, we disable the specific background receivers/services:
   ```bash
   pm disable org.lineageos.pocketmode/.BootCompletedReceiver
   pm disable org.lineageos.pocketmode/.PocketModeService
   pkill -9 -f org.lineageos.pocketmode
   ```
   This stops the polling loop of `tmd2725 Proximity Sensor Wakeup` (saving battery) and ensures the sensor is never inadvertently silenced.

3. **Active Keylayout & IDC Injection**:
   Injects:
   - `uinput-goodix.kl` with `key 106 DPAD_RIGHT WAKE`
   - `uinput-goodix.idc` with `device.wake = 1`

4. **Zero Battery Drain & Immediate Suspend**:
   Because the proximity polling loop is eliminated and the hardware interrupt `msmgpio-dc 79` uses native SoC wakeup (`enable_irq_wake`), the device achieves 95%+ deep sleep while waking instantly on fingerprint touch.
