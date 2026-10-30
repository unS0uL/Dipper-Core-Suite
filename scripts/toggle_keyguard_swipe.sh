#!/system/bin/sh
# scripts/toggle_keyguard_swipe.sh: Lockscreen Swipe-Up Bouncer Reliability Optimizer
# Resolves Keyguard PIN/Pattern bouncer collapse caused by optical proximity misdetection

ACTION="$1"

get_status() {
    threshold="$(device_config get systemui brightline_falsing_proximity_percent_covered_threshold 2>/dev/null | tr -d '\r\n ')"
    case "$threshold" in
        2.0*|2|1.*)
            echo "enabled"
            ;;
        *)
            echo "disabled"
            ;;
    esac
}

case "$ACTION" in
    enable)
        device_config put systemui brightline_falsing_proximity_percent_covered_threshold 2.0 >/dev/null 2>&1
        device_config set_sync_disabled_for_tests persistent >/dev/null 2>&1
        echo "enabled"
        ;;
    disable)
        device_config delete systemui brightline_falsing_proximity_percent_covered_threshold >/dev/null 2>&1
        device_config set_sync_disabled_for_tests none >/dev/null 2>&1
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
