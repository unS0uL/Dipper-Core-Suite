#!/system/bin/sh
# scripts/toggle_watchdog.sh: Clean controller for Audio Ringer Watchdog
MODDIR=${0%/*}/..
ACTION="$1"

get_status() {
    if pgrep -f "audio_watchdog.sh" >/dev/null 2>&1; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

case "$ACTION" in
    enable)
        if ! pgrep -f "audio_watchdog.sh" >/dev/null 2>&1; then
            nohup sh "$MODDIR/audio_watchdog.sh" >/dev/null 2>&1 &
        fi
        echo "enabled"
        ;;
    disable)
        pkill -9 -f "audio_watchdog.sh" 2>/dev/null
        rm -f /dev/dipper_audio_watchdog.pid 2>/dev/null
        echo "disabled"
        ;;
    status)
        get_status
        ;;
    *)
        echo "Usage: $0 {enable|disable|status}"
        exit 1
        ;;
esac
