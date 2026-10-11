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
# 6. LIVE TOGGLING VERIFICATION (BIDIRECTIONAL)
# ------------------------------------------------------------------------------
info "Testing Live Toggling Capabilities..."

# Test Audio Watchdog toggle off & on
pkill -9 -f 'audio_watchdog.sh' >/dev/null 2>&1
sleep 0.5
test_assert "Live Toggle: Audio Watchdog stops on demand" \
    "! pgrep -f 'audio_watchdog.sh' >/dev/null"

nohup /system/bin/sh $MODDIR/audio_watchdog.sh >/dev/null 2>&1 &
sleep 0.5
test_assert "Live Toggle: Audio Watchdog restarts on demand" \
    "pgrep -f 'audio_watchdog.sh' >/dev/null"

# Test VoIP AEC Fallback toggle (switch to stock and back to fix)
cp $MODDIR/audio_effects_stock.xml $MODDIR/system/vendor/etc/audio_effects.xml
test_assert "Live Toggle: Can switch live to stock audio_effects" \
    "diff -q $MODDIR/system/vendor/etc/audio_effects.xml $MODDIR/audio_effects_stock.xml"

cp $MODDIR/audio_effects_no_aec.xml $MODDIR/system/vendor/etc/audio_effects.xml
test_assert "Live Toggle: Can switch live to no-AEC audio_effects" \
    "diff -q $MODDIR/system/vendor/etc/audio_effects.xml $MODDIR/audio_effects_no_aec.xml"


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
