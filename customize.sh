SKIPUNZIP=0

ui_print "****************************************"
ui_print "          Dipper Core Suite             "
ui_print "             by unS0uL                  "
ui_print "****************************************"
ui_print "- Target: Xiaomi Mi 8 (dipper)"
ui_print "- Extracting module files..."

unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >/dev/null 2>&1

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/audio_watchdog.sh" 0 0 0755

ui_print "- Creating boot script link in service.d..."
mkdir -p /data/adb/service.d
cat << 'RUNNER' > /data/adb/service.d/99-dipper-core.sh
#!/system/bin/sh
MODDIR=/data/adb/modules/dipper_core_suite
if [ -d "$MODDIR" ]; then
    sh $MODDIR/service.sh &
    nohup sh $MODDIR/audio_watchdog.sh >/dev/null 2>&1 &
fi
RUNNER
chmod 755 /data/adb/service.d/99-dipper-core.sh

ui_print "- Installation complete!"
ui_print "- Open WebUI anytime via Magisk Action button."
