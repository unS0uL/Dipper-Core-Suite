#!/system/bin/sh
# scripts/toggle_statsd.sh: Clean controller for Statsd & Battery Optimizer
ACTION="$1"

get_status() {
    state="$(getprop init.svc.statsd)"
    if [ "$state" = "running" ]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

case "$ACTION" in
    enable)
        if [ "$(getprop init.svc.statsd)" != "running" ]; then
            resetprop ctl.start statsd
            sleep 1
        fi
        pkill -f co.aospa.sense 2>/dev/null
        pkill -f vendor.qti.hardware.soter 2>/dev/null
        echo "enabled"
        ;;
    disable)
        if [ "$(getprop init.svc.statsd)" = "running" ]; then
            resetprop ctl.stop statsd
        fi
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
