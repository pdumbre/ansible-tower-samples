
#!/bin/bash
# ============================================================
# time_sync.sh
# OS time synchronization via chrony/NTP
# Executed remotely via SSH from jump host
# Merged best of rtclock_sync.sh + time_sync.sh:
#   - Flexible variables from time_sync.sh
#   - Idempotent server-check from rtclock_sync.sh
#   - 3-attempt retry loop from rtclock_sync.sh
#   - Package install + backup + validation from time_sync.sh
# ============================================================

set -e

# ------------------------------------------------------------
# Required environment variables (passed from Ansible):
#   TIME_SYNC_CHRONY_PACKAGE  - e.g. chrony
#   TIME_SYNC_CHRONY_CONFIG   - e.g. /etc/chrony.conf
#   TIME_SYNC_CHRONY_SERVICE  - e.g. chronyd
#   TIME_SYNC_NTP_SERVER      - e.g. pool.ntp.org
#   TIME_SYNC_TIMEZONE        - e.g. UTC
#   TIME_SYNC_FORCE_STEP      - true/false
#   TIME_SYNC_HWCLOCK_SYNC    - true/false
#   TIME_SYNC_BACKUP_CONFIG   - true/false
#   TIME_SYNC_RETRY_DELAY     - seconds e.g. 10
#   TIME_SYNC_MAX_RETRIES     - retry attempts (default 3, per Groovy)
# ------------------------------------------------------------

# Validate required variables
for VAR in TIME_SYNC_CHRONY_PACKAGE TIME_SYNC_CHRONY_CONFIG \
           TIME_SYNC_CHRONY_SERVICE TIME_SYNC_NTP_SERVER \
           TIME_SYNC_TIMEZONE TIME_SYNC_RETRY_DELAY; do
  if [ -z "${!VAR}" ]; then
    echo "[FAIL] Required variable $VAR is not set"
    exit 1
  fi
done

TIME_SYNC_MAX_RETRIES="${TIME_SYNC_MAX_RETRIES:-3}"

# ============================================================
# 1. Ensure chrony is installed
#    Check first — skip install if already present.
#    Avoids "no enabled repositories" error on air-gapped hosts.
# ============================================================
echo "--- [1] Ensuring chrony is installed ---"
if command -v chronyc &>/dev/null; then
  echo "[OK] chrony already installed — skipping package install"
else
  echo "chrony not found — attempting install"
  if command -v yum &>/dev/null; then
    if yum repolist 2>/dev/null | grep -v "^$\|repolist:" | grep -q "."; then
      yum install -y "$TIME_SYNC_CHRONY_PACKAGE"
    else
      echo "[FAIL] No yum repositories available and chrony is not installed"
      exit 1
    fi
  elif command -v dnf &>/dev/null; then
    if dnf repolist enabled 2>/dev/null | grep -v "^$\|Last metadata" | grep -q "."; then
      dnf install -y "$TIME_SYNC_CHRONY_PACKAGE"
    else
      echo "[FAIL] No dnf repositories available and chrony is not installed"
      exit 1
    fi
  elif command -v apt-get &>/dev/null; then
    apt-get install -y "$TIME_SYNC_CHRONY_PACKAGE"
  else
    echo "[FAIL] No supported package manager found (yum/dnf/apt-get)"
    exit 1
  fi
  echo "[OK] $TIME_SYNC_CHRONY_PACKAGE installed"
fi

# ============================================================
# 2. Backup existing chrony configuration
#    (from time_sync.sh — missing in rtclock_sync.sh)
# ============================================================
if [ "${TIME_SYNC_BACKUP_CONFIG:-false}" = "true" ]; then
  echo "--- [2] Backing up chrony configuration ---"
  if cp "$TIME_SYNC_CHRONY_CONFIG" "${TIME_SYNC_CHRONY_CONFIG}.backup" 2>/dev/null; then
    echo "[OK] Backup saved to ${TIME_SYNC_CHRONY_CONFIG}.backup"
  else
    echo "[WARN] Backup skipped — ${TIME_SYNC_CHRONY_CONFIG} not found"
  fi
fi

# ============================================================
# 3. Update chrony.conf — idempotent server check
#    (from rtclock_sync.sh — time_sync.sh always deleted/re-added
#    unconditionally. This version skips if already correct.)
# ============================================================
echo "--- [3] Updating chrony server configuration ---"
EXISTING_SERVER=$(grep "^server" "$TIME_SYNC_CHRONY_CONFIG" || true)

if [ -z "$EXISTING_SERVER" ]; then
  echo "No server line found — adding server $TIME_SYNC_NTP_SERVER"
  echo "server $TIME_SYNC_NTP_SERVER" >> "$TIME_SYNC_CHRONY_CONFIG"
elif echo "$EXISTING_SERVER" | grep -q "$TIME_SYNC_NTP_SERVER"; then
  echo "Server $TIME_SYNC_NTP_SERVER already configured — no change needed"
else
  echo "Replacing existing server line with $TIME_SYNC_NTP_SERVER"
  sed -i '/^server[[:space:]]/d' "$TIME_SYNC_CHRONY_CONFIG"
  echo "server $TIME_SYNC_NTP_SERVER" >> "$TIME_SYNC_CHRONY_CONFIG"
fi

# ============================================================
# 4. Remove pool lines
# ============================================================
echo "--- [4] Removing pool lines from chrony.conf ---"
sed -i '/^pool[[:space:]]/d' "$TIME_SYNC_CHRONY_CONFIG"

# ============================================================
# 5. Enable and restart chronyd
#    (service name from variable — not hardcoded as in rtclock_sync.sh)
# ============================================================
echo "--- [5] Enabling and restarting $TIME_SYNC_CHRONY_SERVICE ---"
systemctl enable "$TIME_SYNC_CHRONY_SERVICE"
systemctl restart "$TIME_SYNC_CHRONY_SERVICE"
sleep 2

# ============================================================
# 6. Display chrony sources
# ============================================================
echo "--- [6] Chrony sources ---"
chronyc -a sources

# ============================================================
# 7. Force chrony burst + makestep
#    (conditional flag from time_sync.sh — rtclock_sync.sh always ran)
# ============================================================
if [ "${TIME_SYNC_FORCE_STEP:-false}" = "true" ]; then
  echo "--- [7] Forcing chrony sync (burst + makestep) ---"
  chronyc -a 'burst 4/4'
  chronyc -a makestep
fi

# ============================================================
# 8. Sync hardware clock
#    (conditional flag from time_sync.sh — rtclock_sync.sh always ran)
# ============================================================
if [ "${TIME_SYNC_HWCLOCK_SYNC:-false}" = "true" ]; then
  echo "--- [8] Syncing hardware clock ---"
  hwclock -w
  echo "[OK] Hardware clock synced"
fi

# ============================================================
# 9. Set timezone
#    (variable from time_sync.sh — rtclock_sync.sh hardcoded UTC)
# ============================================================
echo "--- [9] Setting timezone to $TIME_SYNC_TIMEZONE ---"
timedatectl set-timezone "$TIME_SYNC_TIMEZONE"
echo "[OK] Timezone set to $TIME_SYNC_TIMEZONE"

# ============================================================
# 10. Wait for NTP synchronization to settle
# ============================================================
echo "--- [10] Waiting ${TIME_SYNC_RETRY_DELAY}s for NTP sync to settle ---"
sleep "$TIME_SYNC_RETRY_DELAY"

# ============================================================
# 11. Verify sync with retry loop
#     (3-attempt loop from rtclock_sync.sh — more robust than
#      time_sync.sh which only did 1 check + 1 single retry.
#      MAX_RETRIES is configurable, defaults to 3 per Groovy.)
# ============================================================
echo "--- [11] Verifying NTP synchronization (max $TIME_SYNC_MAX_RETRIES attempts) ---"
SYNC_ERR=true
NTP_ACTIVE=""
NTP_SYNC=""

for i in $(seq 1 "$TIME_SYNC_MAX_RETRIES"); do
  echo "  Attempt $i of $TIME_SYNC_MAX_RETRIES"
  TIMEDATECTL_OUT=$(timedatectl show | tr -d '\r' | sed 's/\[?2004[lh]//g')
  echo "$TIMEDATECTL_OUT"

  NTP_ACTIVE=$(echo "$TIMEDATECTL_OUT" | grep '^NTP='             | cut -d= -f2 | tr -d '[:space:]')
  NTP_SYNC=$(echo   "$TIMEDATECTL_OUT" | grep '^NTPSynchronized=' | cut -d= -f2 | tr -d '[:space:]')

  echo "  NTP            : ${NTP_ACTIVE:-unknown}"
  echo "  NTPSynchronized: ${NTP_SYNC:-unknown}"

  if [ "${NTP_SYNC:-no}" = "yes" ]; then
    SYNC_ERR=false
    break
  else
    if [ "$i" -lt "$TIME_SYNC_MAX_RETRIES" ]; then
      echo "  Not synchronized — retrying chrony sync"
      chronyc -a sources
      chronyc -a 'burst 4/4'
      chronyc -a makestep
      echo "  Waiting ${TIME_SYNC_RETRY_DELAY}s before next attempt"
      sleep "$TIME_SYNC_RETRY_DELAY"
    fi
  fi
done

# ============================================================
# 12. Fail if not synchronized after all retries
# ============================================================
if [ "$SYNC_ERR" = "true" ]; then
  echo "[FAIL] NTP synchronization error after $TIME_SYNC_MAX_RETRIES attempts"
  exit 1
fi

echo "RESULT_NTP=${NTP_ACTIVE:-unknown}"
echo "RESULT_SYNCED=${NTP_SYNC:-no}"
echo "--- Time sync completed successfully ---"
