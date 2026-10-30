# Standalone Dialer Battery Optimizer & Telephony Safety Guard

## Device Target
- **Device:** Xiaomi Mi 8 (`dipper`)
- **OS Platform:** Android 14 (crDroid 10.x / LineageOS 21+)
- **Scope:** Telecom role management, background battery drain prevention, emergency call safety

---

## 1. Problem Description
On custom ROMs such as crDroid and LineageOS, the stock AOSP dialer (`com.android.dialer`) is pre-installed as a system application. Users who prefer Google Phone (`com.google.android.dialer`) or other dialers usually install them and grant them the default phone app role (`android.app.role.DIALER`).

However, the dormant AOSP dialer remains fully enabled in the background:
1. **Background Wakeups**: Registers system receivers (`CallLogReceiver`, `VoicemailProviderChangeReceiver`) and services (`InCallServiceImpl`, `OmtpService`).
2. **Permission Rejection Loops**: Lacking default dialer privileges, background attempts to inspect call records or sync visual voicemail fail with security exceptions, generating repetitive wakeups and CPU wake cycles.
3. **Standby Battery Loss**: Contributes 2-4% unneeded battery consumption during idle and after phone calls.

---

## 2. The Danger of Blindly Disabling `com.android.dialer`
Disabling `com.android.dialer` without strict verification can severely compromise telephony:
- If a user has **NOT** installed Google Dialer (or any other dialer), disabling `com.android.dialer` completely eliminates the system dialer, causing incoming/outgoing calls to fail and blocking emergency calls (911/112).
- If the default dialer role is revoked or reset during ROM updates, a disabled AOSP dialer leaves Android with zero dialers.

---

## 3. The Guarded Solution (`scripts/toggle_dialer.sh`)

The script implements a 5-step strict pre-flight check before touching the system dialer:

```bash
# 1. Query active default dialer via Telecom & RoleManager
DEFAULT_DIALER=$(telecom get-default-dialer)

# 2. Check existence of AOSP dialer
# If not present on system, gracefully exit.

# 3. Guard: No default dialer detected?
# Ensure com.android.dialer remains ENABLED.

# 4. Guard: Is com.android.dialer the active default dialer?
# Ensure com.android.dialer remains ENABLED.

# 5. Guard: Is the alternative dialer installed and functional?
# If valid and default -> safely disable com.android.dialer.
# If invalid or removed -> force re-enable com.android.dialer.
```

### Live Reversibility
- **`auto` / `enable`**: Evaluates system state dynamically. If an alternative dialer is verified as default, `com.android.dialer` is muted.
- **`disable`**: Immediately re-enables `com.android.dialer` via `pm enable com.android.dialer`.
- **`status`**: Reports default dialer and package state (`default_dialer=...|aosp_state=...`).
