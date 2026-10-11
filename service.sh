#!/system/bin/sh
MODDIR=${0%/*}

# 1. Goodix proximity unmask
echo 0 > /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null

# 2. Statsd & Daemon CPU-drain fix
resetprop ctl.start statsd
sleep 1
pkill -f org.lineageos.pocketmode 2>/dev/null
pkill -f co.aospa.sense 2>/dev/null
pkill -f vendor.qti.hardware.soter 2>/dev/null

# 3. Apply FP keylayout bind-mount live if not already mounted
if ! grep -q "uinput-goodix.kl" /proc/mounts; then
    mount -o bind "$MODDIR/system/usr/keylayout/uinput-goodix.kl" /system/usr/keylayout/uinput-goodix.kl 2>/dev/null
fi

# 4. Start Audio Watchdog Daemon in background
pkill -f "audio_watchdog.sh" 2>/dev/null
nohup sh "$MODDIR/audio_watchdog.sh" >/dev/null 2>&1 &
