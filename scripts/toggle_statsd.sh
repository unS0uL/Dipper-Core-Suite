#!/system/bin/sh
# scripts/toggle_statsd.sh: Clean controller for Statsd & Battery Optimizer
ACTION="$1"

case "$ACTION" in
    enable)
        resetprop ctl.start statsd
        sleep 1
        pkill -f co.aospa.sense 2>/dev/null
        pkill -f vendor.qti.hardware.soter 2>/dev/null
        ;;
    disable)
        resetprop ctl.stop statsd
        ;;
    *)
        echo "Usage: $0 {enable|disable}"
        exit 1
        ;;
esac
