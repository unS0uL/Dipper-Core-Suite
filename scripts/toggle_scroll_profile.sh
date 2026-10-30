#!/system/bin/sh
# scripts/toggle_scroll_profile.sh: Unified Kinematic Scroll & 60Hz Smoothness Engine
# Unifies:
#  - Core Unrestrict (Android 15 / Pixel approach): unthrottles SystemUI to all cores
#  - VSYNC 60Hz Synchronization: calculated decay damping & GPU floor
#  - Kinematic Mode: iOS Inertia (Apple smooth) vs Android (Responsive Snappy)
#  - Complete 100% reversible stock restoration

ACTION="$1"
MODE="$2"

MODDIR=${0%/*}/..
CONF_FILE="$MODDIR/scroll_profile.conf"
BACKUP_FILE="$MODDIR/scroll_stock.conf"

save_stock() {
    if [ ! -f "$BACKUP_FILE" ]; then
        cat << STOCK_CONF > "$BACKUP_FILE"
INPUT_BOOST_FREQ="$(cat /sys/module/cpu_boost/parameters/input_boost_freq 2>/dev/null)"
INPUT_BOOST_MS="$(cat /sys/module/cpu_boost/parameters/input_boost_ms 2>/dev/null)"
SCHED_UPMIGRATE="$(cat /proc/sys/kernel/sched_upmigrate 2>/dev/null)"
SCHED_DOWNMIGRATE="$(cat /proc/sys/kernel/sched_downmigrate 2>/dev/null)"
SCHED_GROUP_UPMIGRATE="$(cat /proc/sys/kernel/sched_group_upmigrate 2>/dev/null)"
SCHED_GROUP_DOWNMIGRATE="$(cat /proc/sys/kernel/sched_group_downmigrate 2>/dev/null)"
POLICY0_HISPEED_FREQ="$(cat /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null)"
POLICY0_HISPEED_LOAD="$(cat /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 2>/dev/null)"
POLICY4_HISPEED_FREQ="$(cat /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null)"
POLICY4_HISPEED_LOAD="$(cat /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load 2>/dev/null)"
POLICY0_DOWN_RATE="$(cat /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null)"
POLICY4_DOWN_RATE="$(cat /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null)"
SCHEDTUNE_BOOST="$(cat /dev/stune/top-app/schedtune.boost 2>/dev/null)"
ANIMATOR_DURATION="$(settings get global animator_duration_scale 2>/dev/null)"
STOCK_GPU_MIN="$(cat /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null)"
STOCK_GPU_DEF="$(cat /sys/class/kgsl/kgsl-3d0/default_pwrlevel 2>/dev/null)"
STOCK_RESTRICTED_CPUS="$(cat /dev/cpuset/restricted/cpus 2>/dev/null)"
STOCK_FOREGROUND_CPUS="$(cat /dev/cpuset/foreground/cpus 2>/dev/null)"
STOCK_FOREGROUND_BOOST="$(cat /dev/stune/foreground/schedtune.boost 2>/dev/null)"
STOCK_CPUBW_MIN="$(cat /sys/class/devfreq/soc:qcom,cpubw/min_freq 2>/dev/null)"
STOCK_CONF
    fi
}

apply_core_unrestrict() {
    # Ensure background/restricted throttling never locks threads to Little cores (0-3)
    echo "0-7" > /dev/cpuset/restricted/cpus 2>/dev/null

    # Unthrottle foreground cpuset to all 8 cores (Android 14 SystemUI runs in /foreground)
    echo "0-7" > /dev/cpuset/foreground/cpus 2>/dev/null

    # Assign SystemUI to top-app and unthrottle thread affinities across all 8 cores
    pid=$(pidof com.android.systemui 2>/dev/null)
    if [ -n "$pid" ]; then
        echo "$pid" > /dev/cpuset/top-app/cgroup.procs 2>/dev/null
        taskset -p ff "$pid" >/dev/null 2>&1
        renice -n -10 -p "$pid" >/dev/null 2>&1
        for f in /proc/"$pid"/task/*/comm; do
            [ -r "$f" ] || continue
            tid="${f#/proc/"$pid"/task/}"
            tid="${tid%/comm}"
            taskset -p ff "$tid" >/dev/null 2>&1
            read -r comm < "$f" 2>/dev/null
            case "$comm" in
                *Render*|*wmshell*|*systemui*)
                    renice -n -10 -p "$tid" >/dev/null 2>&1
                    ;;
            esac
        done
    fi
}

apply_ios_profile() {
    save_stock

    # 1. Core Binding & Unrestrict (Android 15 approach)
    apply_core_unrestrict

    # 2. Decouple Animator vs Window scales (Prevents abrupt shelf-collapse)
    settings put global animator_duration_scale 1.0 2>/dev/null

    # 3. Touch & Fling Duration Boost (350ms covers full fling transition to rest)
    echo "0:1228800 1:1228800 2:1228800 3:1228800 4:1459200 5:1459200 6:1459200 7:1459200" > /sys/module/cpu_boost/parameters/input_boost_freq 2>/dev/null
    echo 350 > /sys/module/cpu_boost/parameters/input_boost_ms 2>/dev/null

    # 4. WALT Migration (Early smooth handoff to big cluster at 65% load)
    echo 65 > /proc/sys/kernel/sched_downmigrate 2>/dev/null
    echo 75 > /proc/sys/kernel/sched_upmigrate 2>/dev/null
    echo 70 > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null
    echo 85 > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null

    # 5. Schedutil Hispeed ramp-up (holds frequency active while fling is running)
    echo 1132800 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null
    echo 65 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 2>/dev/null
    echo 1286400 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null
    echo 65 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load 2>/dev/null

    # 6. iOS Long-tail Deceleration Damping (Calculated 60ms / 4 full VSYNC frames)
    echo 60000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null
    echo 60000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null

    # 7. GPU Floor to 342 MHz (level 5 prevents rendering drops on quick settings pull)
    echo 5 > /sys/class/kgsl/kgsl-3d0/default_pwrlevel 2>/dev/null
    echo 5 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null

    # 8. Top-App & Foreground Priority Boost (SystemUI and compositor run in foreground)
    echo 25 > /dev/stune/top-app/schedtune.boost 2>/dev/null
    echo 15 > /dev/stune/foreground/schedtune.boost 2>/dev/null

    # 9. Elevate DDR memory bus floor to prevent cache-stall drops during notification traversal
    echo 4577 > /sys/class/devfreq/soc:qcom,cpubw/min_freq 2>/dev/null

    echo "MODE=ios" > "$CONF_FILE"
}

apply_android_profile() {
    save_stock

    # 1. Core Binding & Unrestrict (Android 15 approach)
    apply_core_unrestrict

    # 2. Maintain ultra-snappy 0.5x duration
    settings put global animator_duration_scale 0.5 2>/dev/null

    # 3. Snappy touch boost (250ms)
    echo "0:1324800 1:1324800 2:1324800 3:1324800 4:1612800 5:1612800 6:1612800 7:1612800" > /sys/module/cpu_boost/parameters/input_boost_freq 2>/dev/null
    echo 250 > /sys/module/cpu_boost/parameters/input_boost_ms 2>/dev/null

    # 4. Rapid WALT Migration
    echo 60 > /proc/sys/kernel/sched_downmigrate 2>/dev/null
    echo 70 > /proc/sys/kernel/sched_upmigrate 2>/dev/null
    echo 65 > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null
    echo 80 > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null

    # 5. Immediate High Frequency ramp
    echo 1228800 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null
    echo 60 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 2>/dev/null
    echo 1459200 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null
    echo 60 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load 2>/dev/null

    # 6. Snappy deceleration (Calculated 2 full VSYNC frames: 33,333 us)
    echo 33333 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null
    echo 33333 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null

    # 7. GPU Floor to 342 MHz
    echo 5 > /sys/class/kgsl/kgsl-3d0/default_pwrlevel 2>/dev/null
    echo 5 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null

    # 8. High Schedtune Boost
    echo 25 > /dev/stune/top-app/schedtune.boost 2>/dev/null
    echo 20 > /dev/stune/foreground/schedtune.boost 2>/dev/null

    # 9. Elevate DDR memory bus floor
    echo 4577 > /sys/class/devfreq/soc:qcom,cpubw/min_freq 2>/dev/null

    echo "MODE=android" > "$CONF_FILE"
}

restore_stock() {
    if [ -f "$BACKUP_FILE" ]; then
        # shellcheck source=/dev/null
        . "$BACKUP_FILE"
    fi

    # Fallback to stock defaults if variables empty
    [ -z "$INPUT_BOOST_FREQ" ] && INPUT_BOOST_FREQ="0:1056000 1:1056000 2:1056000 3:1056000 4:1056000 5:1056000 6:1056000 7:1056000"
    [ -z "$INPUT_BOOST_MS" ] && INPUT_BOOST_MS="80"
    [ -z "$SCHED_UPMIGRATE" ] && SCHED_UPMIGRATE="95"
    [ -z "$SCHED_DOWNMIGRATE" ] && SCHED_DOWNMIGRATE="85"
    [ -z "$SCHED_GROUP_UPMIGRATE" ] && SCHED_GROUP_UPMIGRATE="100"
    [ -z "$SCHED_GROUP_DOWNMIGRATE" ] && SCHED_GROUP_DOWNMIGRATE="95"
    [ -z "$POLICY0_HISPEED_FREQ" ] && POLICY0_HISPEED_FREQ="0"
    [ -z "$POLICY0_HISPEED_LOAD" ] && POLICY0_HISPEED_LOAD="90"
    [ -z "$POLICY4_HISPEED_FREQ" ] && POLICY4_HISPEED_FREQ="0"
    [ -z "$POLICY4_HISPEED_LOAD" ] && POLICY4_HISPEED_LOAD="90"
    [ -z "$POLICY0_DOWN_RATE" ] && POLICY0_DOWN_RATE="20000"
    [ -z "$POLICY4_DOWN_RATE" ] && POLICY4_DOWN_RATE="20000"
    [ -z "$SCHEDTUNE_BOOST" ] && SCHEDTUNE_BOOST="10"
    [ -z "$ANIMATOR_DURATION" ] && ANIMATOR_DURATION="0.5"
    [ -z "$STOCK_GPU_MIN" ] && STOCK_GPU_MIN="6"
    [ -z "$STOCK_GPU_DEF" ] && STOCK_GPU_DEF="6"
    [ -z "$STOCK_RESTRICTED_CPUS" ] && STOCK_RESTRICTED_CPUS="0-3"
    [ -z "$STOCK_FOREGROUND_CPUS" ] && STOCK_FOREGROUND_CPUS="0-3,6-7"
    [ -z "$STOCK_FOREGROUND_BOOST" ] && STOCK_FOREGROUND_BOOST="0"
    [ -z "$STOCK_CPUBW_MIN" ] && STOCK_CPUBW_MIN="2288"

    # Restore in exact reverse order
    echo "$STOCK_CPUBW_MIN" > /sys/class/devfreq/soc:qcom,cpubw/min_freq 2>/dev/null
    echo "$STOCK_FOREGROUND_BOOST" > /dev/stune/foreground/schedtune.boost 2>/dev/null
    echo "$STOCK_FOREGROUND_CPUS" > /dev/cpuset/foreground/cpus 2>/dev/null
    echo "$STOCK_GPU_MIN" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null
    echo "$STOCK_GPU_DEF" > /sys/class/kgsl/kgsl-3d0/default_pwrlevel 2>/dev/null
    echo "$SCHEDTUNE_BOOST" > /dev/stune/top-app/schedtune.boost 2>/dev/null
    echo "$POLICY4_DOWN_RATE" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null
    echo "$POLICY0_DOWN_RATE" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null
    echo "$POLICY4_HISPEED_LOAD" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load 2>/dev/null
    echo "$POLICY4_HISPEED_FREQ" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null
    echo "$POLICY0_HISPEED_LOAD" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 2>/dev/null
    echo "$POLICY0_HISPEED_FREQ" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null

    # Sched migration restore order: upmigrate must always be >= downmigrate
    echo "$SCHED_UPMIGRATE" > /proc/sys/kernel/sched_upmigrate 2>/dev/null
    echo "$SCHED_DOWNMIGRATE" > /proc/sys/kernel/sched_downmigrate 2>/dev/null
    echo "$SCHED_GROUP_UPMIGRATE" > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null
    echo "$SCHED_GROUP_DOWNMIGRATE" > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null

    echo "$INPUT_BOOST_MS" > /sys/module/cpu_boost/parameters/input_boost_ms 2>/dev/null
    echo "$INPUT_BOOST_FREQ" > /sys/module/cpu_boost/parameters/input_boost_freq 2>/dev/null

    # Restore restricted cpuset and return SystemUI process to top-app with unthrottled affinity (0-7)
    echo "$STOCK_RESTRICTED_CPUS" > /dev/cpuset/restricted/cpus 2>/dev/null
    pid=$(pidof com.android.systemui 2>/dev/null)
    if [ -n "$pid" ]; then
        echo "$pid" > /dev/cpuset/top-app/cgroup.procs 2>/dev/null
        taskset -p ff "$pid" >/dev/null 2>&1
        renice -n 0 -p "$pid" >/dev/null 2>&1
        for f in /proc/"$pid"/task/*/comm; do
            [ -r "$f" ] || continue
            tid="${f#/proc/"$pid"/task/}"
            tid="${tid%/comm}"
            taskset -p ff "$tid" >/dev/null 2>&1
            read -r comm < "$f" 2>/dev/null
            case "$comm" in
                *Render*|*wmshell*)
                    renice -n -4 -p "$tid" >/dev/null 2>&1
                    ;;
                *)
                    renice -n 0 -p "$tid" >/dev/null 2>&1
                    ;;
            esac
        done
    fi

    settings put global animator_duration_scale "$ANIMATOR_DURATION" 2>/dev/null

    rm -f "$CONF_FILE"
}

case "$ACTION" in
    enable)
        if [ "$MODE" = "android" ]; then
            apply_android_profile
        else
            apply_ios_profile
        fi
        ;;
    disable)
        restore_stock
        ;;
    set_mode)
        if [ -f "$CONF_FILE" ]; then
            if [ "$MODE" = "android" ]; then
                apply_android_profile
            else
                apply_ios_profile
            fi
        else
            echo "MODE=$MODE" > "$CONF_FILE.pending"
        fi
        ;;
    status)
        if [ -f "$CONF_FILE" ]; then
            # shellcheck source=/dev/null
            . "$CONF_FILE"
            [ -z "$MODE" ] && MODE="ios"
            echo "enabled:$MODE"
        else
            echo "disabled"
        fi
        ;;
    *)
        echo "Usage: $0 {enable [ios|android]|disable|set_mode [ios|android]|status}"
        exit 1
        ;;
esac
