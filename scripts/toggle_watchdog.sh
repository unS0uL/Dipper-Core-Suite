#!/system/bin/sh
# scripts/toggle_watchdog.sh: Clean controller for Audio Ringer Watchdog
MODDIR=${0%/*}/..
ACTION="$1"

case "$ACTION" in
    enable)
        pkill -f "audio_watchdog.sh" 2>/dev/null
        nohup sh "$MODDIR/audio_watchdog.sh" >/dev/null 2>&1 &
        ;;
    disable)
        pkill -9 -f "audio_watchdog.sh" 2>/dev/null
        ;;
    *)
        echo "Usage: $0 {enable|disable}"
        exit 1
        ;;
esac
