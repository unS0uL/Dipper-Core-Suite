#!/system/bin/sh
MODID="dipper_core_suite"
chmod 755 /data/adb /data/adb/modules /data/adb/modules/"$MODID" 2>/dev/null
chmod -R 755 /data/adb/modules/"$MODID"/webroot 2>/dev/null

if pm path io.github.a13e300.ksuwebui >/dev/null 2>&1; then
    am start -n "io.github.a13e300.ksuwebui/.WebUIActivity" -e id "$MODID" -e name "Dipper Core Suite"
elif pm path com.dergoogler.mmrl >/dev/null 2>&1; then
    am start -n "com.dergoogler.mmrl/.ui.activity.webui.WebUIActivity" -e MOD_ID "$MODID"
elif pm path com.dergoogler.mmrl.wx >/dev/null 2>&1; then
    am start -n "com.dergoogler.mmrl.wx/.ui.activity.webui.WebUIActivity" -e MOD_ID "$MODID"
else
    # Fallback: start browser or download KsuWebUI
    am start -a android.intent.action.VIEW -d "https://github.com/5ec1cff/KsuWebUIStandalone/releases"
fi
