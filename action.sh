#!/system/bin/sh
MODID="dipper_core_suite"

if pm path io.github.a13e300.ksuwebui >/dev/null 2>&1; then
    chmod 755 /data/adb 2>/dev/null
    am start -n "io.github.a13e300.ksuwebui/.WebUIActivity" -e id "$MODID" -e name "Dipper Core Suite"
elif pm path com.dergoogler.mmrl.wx >/dev/null 2>&1; then
    chmod 755 /data/adb 2>/dev/null
    am start -n "com.dergoogler.mmrl.wx/.ui.activity.webui.WebUIActivity" -e MOD_ID "$MODID"
else
    # Fallback: start browser or log
    am start -a android.intent.action.VIEW -d "https://github.com/5ec1cff/KsuWebUIStandalone/releases"
fi
