#!/system/bin/sh
# Audio Routing & Ringer Watchdog by unS0uL
# Runs in background, monitors audio mute/routing state, and automatically recovers audio without reboot

PIDFILE="/dev/dipper_audio_watchdog.pid"
if [ -f "$PIDFILE" ]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$old_pid" ] && [ -d "/proc/$old_pid" ]; then
        exit 0
    fi
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE" 2>/dev/null; exit 0' EXIT INT TERM

last_mode=""
log -p i -t "DipperAudioWatchdog" "Started audio watchdog daemon"

while true; do
    current_mode=$(settings get global mode_ringer 2>/dev/null)
    
    if [ -n "$current_mode" ] && [ -n "$last_mode" ] && [ "$last_mode" != "$current_mode" ]; then
        log -p i -t "DipperAudioWatchdog" "Ringer mode changed: $last_mode -> $current_mode"
        # If switched back to NORMAL (2) from SILENT (0) or VIBRATE (1)
        if [ "$current_mode" = "2" ]; then
            sleep 1
            # Check if primary output is stuck in standby or earpiece while it should be speaker
            policy_dump=$(dumpsys media.audio_flinger 2>/dev/null | grep -E "Output devices: 0x1\b")
            muted_streams=$(dumpsys audio 2>/dev/null | grep "ringer mode muted streams" | grep -v "0x0")
            
            if [ -n "$policy_dump" ] || [ -n "$muted_streams" ]; then
                log -p w -t "DipperAudioWatchdog" "Detected muted streams or earpiece stuck on normal mode! Auto-recovering..."
                media volume --stream 3 --set 10 2>/dev/null
                media volume --stream 2 --set 7 2>/dev/null
                pkill -9 -f android.hardware.audio.service
                log -p i -t "DipperAudioWatchdog" "Audio HAL auto-recovered successfully"
            fi
        fi
    fi
    last_mode="$current_mode"
    sleep 2
done
