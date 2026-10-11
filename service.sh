#!/system/bin/sh
MODDIR=${0%/*}

# 1. Permanent Goodix Fingerprint Screen-Off Wake Fix:
# - Unmask Goodix HW IRQ in kernel driver (gf_spi)
# - Lock proximity_state node to 0 (read-only 0444) to prevent driver/HAL race
# - Disable buggy XiaomiPocketMode components that shut down Goodix IRQ when held in hand
chmod 0644 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null
echo -n 0 > /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null
chmod 0444 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null

pm disable org.lineageos.pocketmode/.BootCompletedReceiver 2>/dev/null
pm disable org.lineageos.pocketmode/.PocketModeService 2>/dev/null
pkill -9 -f org.lineageos.pocketmode 2>/dev/null

# 2. Statsd & Daemon CPU-drain fix
resetprop ctl.start statsd
sleep 1
pkill -f co.aospa.sense 2>/dev/null
pkill -f vendor.qti.hardware.soter 2>/dev/null

# 3. Apply FP keylayout & IDC bind-mount live if not already mounted
if ! grep -q "uinput-goodix.kl" /proc/mounts; then
    mount -o bind "$MODDIR/system/usr/keylayout/uinput-goodix.kl" /system/usr/keylayout/uinput-goodix.kl 2>/dev/null
fi
if [ -f "$MODDIR/system/usr/idc/uinput-goodix.idc" ] && ! grep -q "uinput-goodix.idc" /proc/mounts; then
    mount -o bind "$MODDIR/system/usr/idc/uinput-goodix.idc" /system/usr/idc/uinput-goodix.idc 2>/dev/null
fi

# 4. Start Audio Watchdog Daemon in background
pkill -f "audio_watchdog.sh" 2>/dev/null
nohup sh "$MODDIR/audio_watchdog.sh" >/dev/null 2>&1 &
