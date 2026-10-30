#!/system/bin/sh
# scripts/toggle_dialer.sh: Safe, Guarded Standalone Dialer Optimizer
# Prevents duplicate background drain from AOSP dialer when a custom dialer (e.g. Google Dialer) is active.
# Author: unS0uL

ACTION="${1:-auto}"
AOSP_DIALER="com.android.dialer"

get_default_dialer() {
    def="$(telecom get-default-dialer 2>/dev/null | tr -d '\r\n')"
    if [ -z "$def" ]; then
        def="$(cmd role get-role-holders android.app.role.DIALER 2>/dev/null | head -n 1 | tr -d '\r\n')"
    fi
    echo "$def"
}

is_package_installed() {
    pkg="$1"
    pm list packages "$pkg" 2>/dev/null | grep -q "^package:${pkg}$"
}

case "$ACTION" in
    auto|enable)
        # 1. Resolve current default dialer
        DEFAULT_DIALER="$(get_default_dialer)"

        # 2. Safety Guard: Check if AOSP dialer even exists on this ROM
        if ! is_package_installed "$AOSP_DIALER"; then
            echo "AOSP dialer ($AOSP_DIALER) is not installed on this system. Skipping."
            exit 0
        fi

        # 3. Safety Guard: If no default dialer is detected, DO NOT touch AOSP dialer
        if [ -z "$DEFAULT_DIALER" ]; then
            echo "No default dialer detected. Ensuring $AOSP_DIALER remains enabled for emergency/call safety."
            pm enable "$AOSP_DIALER" >/dev/null 2>&1
            exit 0
        fi

        # 4. Safety Guard: If AOSP dialer is the active default dialer, DO NOT disable it
        if [ "$DEFAULT_DIALER" = "$AOSP_DIALER" ]; then
            echo "$AOSP_DIALER is currently the primary default dialer. Ensuring it remains enabled."
            pm enable "$AOSP_DIALER" >/dev/null 2>&1
            exit 0
        fi

        # 5. Safety Guard: Ensure the alternative default dialer is genuinely installed and functional
        if ! is_package_installed "$DEFAULT_DIALER"; then
            echo "Alternative dialer ($DEFAULT_DIALER) not detected in installed packages. Keeping $AOSP_DIALER enabled."
            pm enable "$AOSP_DIALER" >/dev/null 2>&1
            exit 0
        fi

        # 6. Safe to optimize: Alternative dialer is active and verified default
        echo "Alternative dialer active ($DEFAULT_DIALER). Safely disabling duplicate $AOSP_DIALER to eliminate background battery drain."
        pm disable "$AOSP_DIALER" >/dev/null 2>&1
        ;;

    disable)
        # Restoration: Unconditionally restore AOSP dialer to enabled state
        echo "Restoring $AOSP_DIALER to fully enabled state."
        pm enable "$AOSP_DIALER" >/dev/null 2>&1
        ;;

    status)
        DEFAULT_DIALER="$(get_default_dialer)"
        if is_package_installed "$AOSP_DIALER"; then
            STATE="$(pm list packages -d 2>/dev/null | grep -q "^package:${AOSP_DIALER}$" && echo "disabled" || echo "enabled")"
        else
            STATE="not_installed"
        fi
        echo "default_dialer=$DEFAULT_DIALER|aosp_state=$STATE"
        ;;

    *)
        echo "Usage: $0 {auto|enable|disable|status}"
        exit 1
        ;;
esac
