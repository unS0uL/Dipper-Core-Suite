#!/system/bin/sh
MODDIR=${0%/*}

# 0. Ensure WebUI access permissions
chmod 755 /data/adb 2>/dev/null
chmod 755 /data/adb/modules 2>/dev/null
chmod 755 "$MODDIR" 2>/dev/null
chmod -R 755 "$MODDIR/webroot" 2>/dev/null

# 1. Enable Permanent Goodix Fingerprint Screen-Off Wake Fix:
sh "$MODDIR/scripts/toggle_fp.sh" enable

# 2. Enable Statsd & Battery Optimizer:
sh "$MODDIR/scripts/toggle_statsd.sh" enable

# 3. Start Audio Watchdog Daemon:
sh "$MODDIR/scripts/toggle_watchdog.sh" enable
