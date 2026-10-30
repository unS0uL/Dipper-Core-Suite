#!/system/bin/sh
# shellcheck shell=sh
# shellcheck disable=SC2034
SKIPUNZIP=0

ui_print "****************************************"
ui_print "          Dipper Core Suite             "
ui_print "             by unS0uL                  "
ui_print "****************************************"
ui_print "- Target: Xiaomi Mi 8 (dipper)"
ui_print "- Extracting module files..."

unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >/dev/null 2>&1

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
set_perm_recursive "$MODPATH/tools" 0 0 0755 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/audio_watchdog.sh" 0 0 0755
chmod 755 /data/adb 2>/dev/null

# Clean up legacy service.d runner if present
rm -f /data/adb/service.d/99-dipper-core.sh 2>/dev/null

# Hot-Reload Live Apply (Zero-Reboot update engine)
LIVE_MODPATH="/data/adb/modules/dipper_core_suite"
if $BOOTMODE && [ "$MODPATH" != "$LIVE_MODPATH" ]; then
    ui_print "- [Hot-Reload] Syncing live module files..."
    mkdir -p "$LIVE_MODPATH"
    cp -af "$MODPATH/." "$LIVE_MODPATH/"
    
    # Preserve existing user scroll preference if present
    if [ -f "$LIVE_MODPATH/scroll_profile.conf" ]; then
        cp -af "$LIVE_MODPATH/scroll_profile.conf" "$MODPATH/scroll_profile.conf" 2>/dev/null
    fi

    ui_print "- [Hot-Reload] Applying tweaks live without reboot..."
    # Apply tweaks directly via live service runner
    sh "$LIVE_MODPATH/service.sh" >/dev/null 2>&1 &

    ui_print "- [Hot-Reload] Live update applied! Reboot NOT required."
fi

ui_print "- Installation complete!"
ui_print "- Open WebUI anytime via Magisk Action button."

