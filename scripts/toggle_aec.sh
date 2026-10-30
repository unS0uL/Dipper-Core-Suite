#!/system/bin/sh
# scripts/toggle_aec.sh: Clean, reversible controller for VoIP AEC Fallback
MODDIR=${0%/*}/..
ACTION="$1"

get_status() {
    if grep -q "audio_effects_no_aec.xml" /proc/mounts 2>/dev/null; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

case "$ACTION" in
    enable)
        # 1. Apply no-AEC configuration with proper SELinux context
        cp "$MODDIR/audio_effects_no_aec.xml" "$MODDIR/system/vendor/etc/audio_effects.xml" 2>/dev/null
        chcon u:object_r:vendor_configs_file:s0 "$MODDIR/audio_effects_no_aec.xml" 2>/dev/null
        chcon u:object_r:vendor_configs_file:s0 "$MODDIR/system/vendor/etc/audio_effects.xml" 2>/dev/null

        # 2. Idempotent bind mount
        if ! grep -q "audio_effects_no_aec.xml" /proc/mounts 2>/dev/null; then
            mount -o bind "$MODDIR/audio_effects_no_aec.xml" /vendor/etc/audio_effects.xml 2>/dev/null
        fi

        # 3. Reload audio subsystem cleanly
        pkill -9 -f android.hardware.audio.service 2>/dev/null
        killall -9 audioserver 2>/dev/null
        echo "enabled"
        ;;

    disable)
        # REVERSE ORDER RESTORATION (Restore stock Qualcomm AEC):
        # 3 (reversed). Unmount bind first
        if grep -q "audio_effects_no_aec.xml" /proc/mounts 2>/dev/null; then
            umount -l /vendor/etc/audio_effects.xml 2>/dev/null
        fi

        # 2 (reversed). Restore stock XML and context
        cp "$MODDIR/audio_effects_stock.xml" "$MODDIR/system/vendor/etc/audio_effects.xml" 2>/dev/null
        chcon u:object_r:vendor_configs_file:s0 "$MODDIR/system/vendor/etc/audio_effects.xml" 2>/dev/null

        # 1 (reversed). Reload audio subsystem cleanly
        pkill -9 -f android.hardware.audio.service 2>/dev/null
        killall -9 audioserver 2>/dev/null
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
