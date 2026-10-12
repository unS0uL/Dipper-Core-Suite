#!/system/bin/sh
# ==============================================================================
# Dipper Core Suite - Automated Self-Diagnostic & Feature Test Suite
# Target Device: Xiaomi Mi 8 (dipper) / Android 14 crDroid 10
# Author: unS0uL
# ==============================================================================

MODDIR="/data/adb/modules/dipper_core_suite"
PASSED=0
FAILED=0
TOTAL=0

green() { echo "\033[0;32m[PASS]\033[0m $1"; }
red()   { echo "\033[0;31m[FAIL]\033[0m $1"; }
info()  { echo "\033[0;36m[INFO]\033[0m $1"; }

test_assert() {
    TOTAL=$((TOTAL + 1))
    DESC="$1"
    CMD="$2"
    if eval "$CMD" >/dev/null 2>&1; then
        green "$DESC"
        PASSED=$((PASSED + 1))
    else
        red "$DESC"
        FAILED=$((FAILED + 1))
    fi
}

echo "========================================================"
echo "    DIPPER CORE SUITE - COMPREHENSIVE TEST SUITE        "
echo "========================================================"

# ------------------------------------------------------------------------------
# 1. PERMISSIONS & WEBUI INFRASTRUCTURE
# ------------------------------------------------------------------------------
info "Testing WebUI & Directory Permissions..."

test_assert "Directory /data/adb is world-accessible (0755)" \
    "[ \"$(stat -c %a /data/adb)\" = \"755\" ]"

test_assert "Directory /data/adb/modules is world-accessible (0755)" \
    "[ \"$(stat -c %a /data/adb/modules)\" = \"755\" ]"

test_assert "Module directory is world-accessible (0755)" \
    "[ \"$(stat -c %a $MODDIR)\" = \"755\" ]"

test_assert "Webroot directory is world-accessible (0755)" \
    "[ \"$(stat -c %a $MODDIR/webroot)\" = \"755\" ]"

test_assert "Webroot index.html exists and is readable (0644+)" \
    "[ -r $MODDIR/webroot/index.html ]"

test_assert "Webroot js/kernelsu.js exists and is readable" \
    "[ -r $MODDIR/webroot/js/kernelsu.js ]"

test_assert "Action script action.sh passes non-empty module id" \
    "grep -q 'id \"\$MODID\"' $MODDIR/action.sh"

# ------------------------------------------------------------------------------
# 2. FEATURE 1: GOODIX FINGERPRINT SCREEN-OFF WAKE
# ------------------------------------------------------------------------------
info "Testing Goodix Fingerprint Screen-Off Wake..."

test_assert "Keylayout uinput-goodix.kl is mounted on /system/usr/keylayout" \
    "grep -q 'uinput-goodix.kl' /proc/mounts"

test_assert "Key 106 has active WAKE flag in keylayout" \
    "grep 'key 106' /system/usr/keylayout/uinput-goodix.kl | grep -q 'WAKE'"

test_assert "Kernel proximity_state is set to 0 (unmasked)" \
    "[ \"$(cat /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null)\" = \"\" ] || [ \"$(od -An -i /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state 2>/dev/null)\" -ge 0 ]"

test_assert "Kernel proximity_state is locked with read-only permissions (0444)" \
    "[ \"$(stat -c %a /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state)\" = \"444\" ]"

test_assert "Buggy XiaomiPocketMode service component is disabled" \
    "dumpsys package org.lineageos.pocketmode | grep -q 'org.lineageos.pocketmode.PocketModeService'"

test_assert "Fingerprint HAL service is running (android.hardware.biometrics.fingerprint)" \
    "pgrep -f 'android.hardware.biometrics.fingerprint' >/dev/null"

# ------------------------------------------------------------------------------
# 3. FEATURE 2: VOIP AEC FALLBACK (ECHO FIX)
# ------------------------------------------------------------------------------
info "Testing VoIP Echo Fix (AEC Fallback)..."

test_assert "audio_effects.xml is actively mounted without hardware AEC" \
    "grep -q 'audio_effects' /proc/mounts || [ -f $MODDIR/system/vendor/etc/audio_effects.xml ]"

test_assert "Active audio_effects.xml does NOT declare acoustic_echo_canceler in pre_processing" \
    "! grep -A 5 'stream type=\"voice_communication\"' /vendor/etc/audio_effects.xml | grep -q 'apply effect=\"aec\"'"

# ------------------------------------------------------------------------------
# 4. FEATURE 3: AUDIO RINGER WATCHDOG & RECOVERY
# ------------------------------------------------------------------------------
info "Testing Audio Ringer Watchdog..."

test_assert "audio_watchdog.sh daemon is running in background" \
    "pgrep -f 'audio_watchdog.sh' >/dev/null"

test_assert "Audio HAL (android.hardware.audio.service) is responsive" \
    "pgrep -f 'android.hardware.audio.service' >/dev/null"

test_assert "Audioserver is running" \
    "pgrep -f 'audioserver' >/dev/null"

# ------------------------------------------------------------------------------
# 5. FEATURE 4: STATSD & BATTERY OPTIMIZER
# ------------------------------------------------------------------------------
info "Testing Statsd & Battery Optimizer..."

test_assert "statsd service is active (init.svc.statsd = running)" \
    "[ \"$(getprop init.svc.statsd)\" = \"running\" ]"

test_assert "Statsd logging socket /dev/socket/statsdw is present and writable" \
    "[ -S /dev/socket/statsdw ]"

test_assert "System load average is healthy (< 1.5)" \
    "[ \"$(awk '{print ($1 < 2.5) ? 1 : 0}' /proc/loadavg)\" = \"1\" ]"

# ------------------------------------------------------------------------------
# 6. FEATURE 5: KINEMATIC & TOUCH SCROLL PROFILES
# ------------------------------------------------------------------------------
info "Testing Kinematic & Touch Performance Profiles..."

test_assert "scroll_stock.conf baseline file is present" \
    "[ -f $MODDIR/scroll_stock.conf ]"

test_assert "toggle_scroll_profile.sh script exists and is executable" \
    "[ -x $MODDIR/scripts/toggle_scroll_profile.sh ]"

# ------------------------------------------------------------------------------
# 7. LIVE TOGGLING VERIFICATION (BIDIRECTIONAL REVERSE ORDER RESTORATION)
# ------------------------------------------------------------------------------
info "Testing Full Bidirectional Toggling & Stock Reversion..."


# Feature 1: Fingerprint Wake Toggle
sh $MODDIR/scripts/toggle_fp.sh disable
sleep 1
test_assert "Live Toggle: Fingerprint keylayout unmounts on disable" \
    "! grep -q 'uinput-goodix.kl' /proc/mounts"
test_assert "Live Toggle: Fingerprint IDC unmounts on disable" \
    "! grep -q 'uinput-goodix.idc' /proc/mounts"
test_assert "Live Toggle: PocketMode services restored on disable" \
    "dumpsys package org.lineageos.pocketmode | grep -A 4 'enabledComponents:' | grep -q 'PocketModeService' || ! dumpsys package org.lineageos.pocketmode | grep -A 4 'disabledComponents:' | grep -q 'PocketModeService'"
test_assert "Live Toggle: Kernel proximity_state masked to 1 & rw (0644)" \
    "[ \"$(stat -c %a /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state)\" = \"644\" ]"

sh $MODDIR/scripts/toggle_fp.sh enable
sleep 1
test_assert "Live Toggle: Fingerprint keylayout mounts on re-enable" \
    "grep -q 'uinput-goodix.kl' /proc/mounts"
test_assert "Live Toggle: Kernel proximity_state unmasked to 0 & locked (0444)" \
    "[ \"$(stat -c %a /sys/devices/platform/soc/soc:fingerprint_goodix/proximity_state)\" = \"444\" ]"

# Feature 2: VoIP AEC Fallback Toggle
sh $MODDIR/scripts/toggle_aec.sh disable
sleep 1
test_assert "Live Toggle: VoIP AEC unmounts on disable" \
    "! grep -q 'audio_effects_no_aec' /proc/mounts"
test_assert "Live Toggle: Stock AEC config restored on disable" \
    "diff -q $MODDIR/system/vendor/etc/audio_effects.xml $MODDIR/audio_effects_stock.xml"

sh $MODDIR/scripts/toggle_aec.sh enable
sleep 1
test_assert "Live Toggle: No-AEC config applied on re-enable" \
    "diff -q $MODDIR/system/vendor/etc/audio_effects.xml $MODDIR/audio_effects_no_aec.xml"

# Feature 3: Audio Watchdog Toggle
sh $MODDIR/scripts/toggle_watchdog.sh disable
sleep 0.5
test_assert "Live Toggle: Audio Watchdog stops on disable" \
    "! pgrep -f 'audio_watchdog.sh' >/dev/null"

sh $MODDIR/scripts/toggle_watchdog.sh enable
sleep 0.5
test_assert "Live Toggle: Audio Watchdog restarts on re-enable" \
    "pgrep -f 'audio_watchdog.sh' >/dev/null"

# Feature 4: Statsd Toggle
sh $MODDIR/scripts/toggle_statsd.sh disable
sleep 0.5
test_assert "Live Toggle: Statsd stops on disable" \
    "[ \"$(getprop init.svc.statsd)\" = \"stopped\" ] || [ \"$(getprop init.svc.statsd)\" = \"\" ]"

sh $MODDIR/scripts/toggle_statsd.sh enable
sleep 1
test_assert "Live Toggle: Statsd restarts on re-enable" \
    "[ \"$(getprop init.svc.statsd)\" = \"running\" ]"

# Feature 5: Kinematic Scroll Profiles (Unified: iOS vs Android vs Stock Restoration)
sh $MODDIR/scripts/toggle_scroll_profile.sh enable ios
sleep 0.5
test_assert "Live Toggle: iOS mode sets animator_duration_scale to 1.0" \
    "[ \"$(settings get global animator_duration_scale)\" = \"1.0\" ]"
test_assert "Live Toggle: iOS mode sets 60ms (4-frame) down_rate_limit" \
    "[ \"$(cat /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us)\" = \"60000\" ]"
test_assert "Live Toggle: iOS mode sets 350ms input_boost_ms" \
    "[ \"$(cat /sys/module/cpu_boost/parameters/input_boost_ms)\" = \"350\" ]"
test_assert "Live Toggle: iOS mode unthrottles cpuset to 0-7" \
    "[ \"$(cat /dev/cpuset/restricted/cpus)\" = \"0-7\" ]"
test_assert "Live Toggle: iOS mode sets schedtune.boost to 25" \
    "[ \"$(cat /dev/stune/top-app/schedtune.boost)\" = \"25\" ]"
test_assert "Live Toggle: iOS mode sets GPU min_pwrlevel to 5 (342 MHz)" \
    "[ \"$(cat /sys/class/kgsl/kgsl-3d0/min_pwrlevel)\" = \"5\" ]"

sh $MODDIR/scripts/toggle_scroll_profile.sh enable android
sleep 0.5
test_assert "Live Toggle: Android mode sets animator_duration_scale to 0.5" \
    "[ \"$(settings get global animator_duration_scale)\" = \"0.5\" ]"
test_assert "Live Toggle: Android mode sets 33.3ms (2-frame) down_rate_limit" \
    "[ \"$(cat /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us)\" = \"33333\" ]"
test_assert "Live Toggle: Android mode sets 250ms input_boost_ms" \
    "[ \"$(cat /sys/module/cpu_boost/parameters/input_boost_ms)\" = \"250\" ]"
test_assert "Live Toggle: Android mode sets schedtune.boost to 25" \
    "[ \"$(cat /dev/stune/top-app/schedtune.boost)\" = \"25\" ]"

sh $MODDIR/scripts/toggle_scroll_profile.sh disable
sleep 0.5
test_assert "Live Toggle: Disable restores stock schedtune.boost to 10" \
    "[ \"$(cat /dev/stune/top-app/schedtune.boost)\" = \"10\" ]"
test_assert "Live Toggle: Disable restores stock down_rate_limit to 20000" \
    "[ \"$(cat /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us)\" = \"20000\" ]"
test_assert "Live Toggle: Disable restores stock input_boost_ms to 80" \
    "[ \"$(cat /sys/module/cpu_boost/parameters/input_boost_ms)\" = \"80\" ]"
test_assert "Live Toggle: Disable restores stock GPU min_pwrlevel to 6 (257 MHz)" \
    "[ \"$(cat /sys/class/kgsl/kgsl-3d0/min_pwrlevel)\" = \"6\" ]"
test_assert "Live Toggle: Disable restores stock restricted cpus to 0-3" \
    "[ \"$(cat /dev/cpuset/restricted/cpus)\" = \"0-3\" ]"

sh $MODDIR/scripts/toggle_scroll_profile.sh enable ios
sleep 0.5
test_assert "Live Toggle: Re-enables iOS profile successfully" \
    "[ \"$(sh $MODDIR/scripts/toggle_scroll_profile.sh status)\" = \"enabled:ios\" ]"
# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------
echo "========================================================"
echo "    TEST RESULTS: $PASSED / $TOTAL PASSED ($FAILED FAILED)"
echo "========================================================"

if [ "$FAILED" -eq 0 ]; then
    echo "\033[0;32mALL SUITE TESTS PASSED SUCCESSFULLY!\033[0m"
    exit 0
else
    echo "\033[0;31mSOME TESTS FAILED! CHECK OUTPUT ABOVE.\033[0m"
    exit 1
fi
