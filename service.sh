#!/system/bin/sh
MODDIR=${0%/*}

# 0. Ensure WebUI access permissions
chmod 755 /data/adb 2>/dev/null
chmod 755 /data/adb/modules 2>/dev/null
chmod 755 "$MODDIR" 2>/dev/null
chmod -R 755 "$MODDIR/webroot" 2>/dev/null

# 1. Early Hardware & Kernel Tweaks (immediate, no framework dependencies):
sh "$MODDIR/scripts/toggle_fp.sh" enable
sh "$MODDIR/scripts/toggle_watchdog.sh" enable

# 2. Late Framework Tweaks (runs asynchronously once system_server and Android framework are ready):
(
    timeout=60
    while [ "$timeout" -gt 0 ] && [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
        timeout=$((timeout - 2))
    done

    # Enable Statsd & Battery Optimizer:
    sh "$MODDIR/scripts/toggle_statsd.sh" enable

    # Start Kinematic & Touch Performance Profile (default: iOS physics):
    sh "$MODDIR/scripts/toggle_scroll_profile.sh" enable ios

    # Safe Standalone Dialer Optimizer (disables duplicate AOSP dialer only if another dialer is default):
    sh "$MODDIR/scripts/toggle_dialer.sh" auto

    # Lockscreen Swipe-Up Bouncer Reliability Fix (prevents false touch rejection via optical proximity):
    sh "$MODDIR/scripts/toggle_keyguard_swipe.sh" enable
) &
