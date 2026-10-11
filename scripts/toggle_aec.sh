#!/system/bin/sh
# scripts/toggle_aec.sh: Clean, reversible controller for VoIP AEC Fallback
MODDIR=${0%/*}/..
ACTION="$1"

case "$ACTION" in
    enable)
        # Apply no-AEC configuration
        cp "$MODDIR/audio_effects_no_aec.xml" "$MODDIR/system/vendor/etc/audio_effects.xml" 2>/dev/null
        mount -o bind "$MODDIR/audio_effects_no_aec.xml" /vendor/etc/audio_effects.xml 2>/dev/null

        # Reload audio subsystem cleanly
        pkill -9 -f android.hardware.audio.service 2>/dev/null
        killall -9 audioserver 2>/dev/null
        ;;

    disable)
        # REVERSE ORDER RESTORATION (Restore stock Qualcomm AEC):
        umount -l /vendor/etc/audio_effects.xml 2>/dev/null
        cp "$MODDIR/audio_effects_stock.xml" "$MODDIR/system/vendor/etc/audio_effects.xml" 2>/dev/null

        # Reload audio subsystem cleanly
        pkill -9 -f android.hardware.audio.service 2>/dev/null
        killall -9 audioserver 2>/dev/null
        ;;
    *)
        echo "Usage: $0 {enable|disable}"
        exit 1
        ;;
esac
