#!/system/bin/sh
# scripts/toggle_fp.sh: Clean, reversible controller for Fingerprint Screen-Off Wake
MODDIR=${0%/*}/..
ACTION="$1"

case "$ACTION" in
    enable)
        # 1. Unmask Goodix HW IRQ in kernel driver (gf_spi)
        chmod 0644 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null
        printf '0' > /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null
        chmod 0444 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null

        # 2. Neutralize buggy XiaomiPocketMode service components
        pm disable org.lineageos.pocketmode/.BootCompletedReceiver 2>/dev/null
        pm disable org.lineageos.pocketmode/.PocketModeService 2>/dev/null
        pkill -9 -f org.lineageos.pocketmode 2>/dev/null

        # 3. Mount active WAKE keylayout and IDC
        if ! grep -q "uinput-goodix.kl" /proc/mounts; then
            mount -o bind "$MODDIR/system/usr/keylayout/uinput-goodix.kl" /system/usr/keylayout/uinput-goodix.kl 2>/dev/null
        fi
        if [ -f "$MODDIR/system/usr/idc/uinput-goodix.idc" ] && ! grep -q "uinput-goodix.idc" /proc/mounts; then
            mount -o bind "$MODDIR/system/usr/idc/uinput-goodix.idc" /system/usr/idc/uinput-goodix.idc 2>/dev/null
        fi

        # 4. Restart Biometrics HAL cleanly
        pkill -9 -f android.hardware.biometrics.fingerprint 2>/dev/null
        ;;

    disable)
        # REVERSE ORDER RESTORATION (Exact stock state):

        # 3 (reversed). Unmount keylayout and IDC first
        umount -l /system/usr/keylayout/uinput-goodix.kl 2>/dev/null
        umount -l /system/usr/idc/uinput-goodix.idc 2>/dev/null

        # 2 (reversed). Re-enable stock XiaomiPocketMode components
        pm enable org.lineageos.pocketmode/.BootCompletedReceiver 2>/dev/null
        pm enable org.lineageos.pocketmode/.PocketModeService 2>/dev/null
        am start-service org.lineageos.pocketmode/.PocketModeService 2>/dev/null

        # 1 (reversed). Mask HW IRQ in kernel and restore default read-write permissions
        chmod 0644 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null
        printf '1' > /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null
        chmod 0644 /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null

        # 4. Restart Biometrics HAL cleanly
        pkill -9 -f android.hardware.biometrics.fingerprint 2>/dev/null
        ;;
    *)
        echo "Usage: $0 {enable|disable}"
        exit 1
        ;;
esac
