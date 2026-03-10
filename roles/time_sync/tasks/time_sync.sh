#!/bin/bash
# ============================================================
# time_sync.sh
# OS time synchronization via chrony/NTP
# Executed remotely via SSH from jump host
# Variables passed as environment variables from Ansible
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

# ============================================================
# PHASE 2: Configure OS time synchronization via chrony/NTP
# ============================================================

# ------------------------------------------------------------
# 1. Ensure chrony is installed
#    (replaces: package module)
# ------------------------------------------------------------
echo "--- [1] Ensuring chrony is installed ---"
if command -v yum &>/dev/null; then
  yum install -y "$TIME_SYNC_CHRONY_PACKAGE"
elif command -v apt-get &>/dev/null; then
  apt-get install -y "$TIME_SYNC_CHRONY_PACKAGE"
elif command -v dnf &>/dev/null; then
  dnf install -y "$TIME_SYNC_CHRONY_PACKAGE"
else
  echo "[FAIL] No supported package manager found (yum/dnf/apt-get)"
  exit 1
fi
echo "[OK] $TIME_SYNC_CHRONY_PACKAGE installed"

# ------------------------------------------------------------
# 2. Backup existing chrony configuration
#    (replaces: copy module with remote_src + failed_when: false)
# ------------------------------------------------------------
if [ "${TIME_SYNC_BACKUP_CONFIG:-false}" = "true" ]; then
  echo "--- [2] Backing up chrony configuration ---"
  if cp "$TIME_SYNC_CHRONY_CONFIG" "${TIME_SYNC_CHRONY_CONFIG}.backup" 2>/dev/null; then
    echo "[OK] Backup saved to ${TIME_SYNC_CHRONY_CONFIG}.backup"
  else
    echo "[WARN] Backup skipped — ${TIME_SYNC_CHRONY_CONFIG} not found"
  fi
fi

# ------------------------------------------------------------
# 3. Display existing NTP server configuration
#    (replaces: grep shell task + debug display)
# ------------------------------------------------------------
echo "--- [3] Existing NTP server configuration ---"
grep "^server" "$TIME_SYNC_CHRONY_CONFIG" || echo "(none found)"

# ------------------------------------------------------------
# 4. Remove existing server and pool lines, add new server
#    (replaces: lineinfile remove server, remove pool, add server)
# ------------------------------------------------------------
echo "--- [4] Updating chrony.conf ---"
sed -i '/^server[[:space:]]/d' "$TIME_SYNC_CHRONY_CONFIG"
sed -i '/^pool[[:space:]]/d'   "$TIME_SYNC_CHRONY_CONFIG"
echo "server $TIME_SYNC_NTP_SERVER" >> "$TIME_SYNC_CHRONY_CONFIG"
echo "[OK] Added: server $TIME_SYNC_NTP_SERVER"

# ------------------------------------------------------------
# 5. Enable and restart chronyd
#    (replaces: systemd enable + systemd restart + 2s pause)
# ------------------------------------------------------------
echo "--- [5] Enabling and restarting $TIME_SYNC_CHRONY_SERVICE ---"
systemctl enable "$TIME_SYNC_CHRONY_SERVICE"
systemctl restart "$TIME_SYNC_CHRONY_SERVICE"
sleep 2

# ------------------------------------------------------------
# 6. Check and display chrony sources
#    (replaces: chronyc sources command + debug display)
# ------------------------------------------------------------
echo "--- [6] Chrony sources ---"
chronyc -a sources

# ------------------------------------------------------------
# 7. Force chrony burst + makestep if requested
#    (replaces: chronyc burst task + chronyc makestep task)
# ------------------------------------------------------------
if [ "${TIME_SYNC_FORCE_STEP:-false}" = "true" ]; then
  echo "--- [7] Forcing chrony sync (burst + makestep) ---"
  chronyc -a 'burst 4/4'
  chronyc -a makestep
fi

# ------------------------------------------------------------
# 8. Sync hardware clock with system time
#    (replaces: hwclock -w task)
# ------------------------------------------------------------
if [ "${TIME_SYNC_HWCLOCK_SYNC:-false}" = "true" ]; then
  echo "--- [8] Syncing hardware clock ---"
  hwclock -w
  echo "[OK] Hardware clock synced"
fi

# ------------------------------------------------------------
# 9. Set timezone
#    (replaces: timedatectl set-timezone task)
# ------------------------------------------------------------
echo "--- [9] Setting timezone to $TIME_SYNC_TIMEZONE ---"
timedatectl set-timezone "$TIME_SYNC_TIMEZONE"
echo "[OK] Timezone set to $TIME_SYNC_TIMEZONE"

# ------------------------------------------------------------
# 10. Wait for NTP synchronization
#     (replaces: pause seconds=time_sync_retry_delay)
# ------------------------------------------------------------
echo "--- [10] Waiting ${TIME_SYNC_RETRY_DELAY}s for NTP sync to settle ---"
sleep "$TIME_SYNC_RETRY_DELAY"

# ------------------------------------------------------------
# 11. Verify NTP synchronization — attempt 1
#     (replaces: timedatectl show + parse + convert + display)
# ------------------------------------------------------------
echo "--- [11] Verifying NTP synchronization (attempt 1) ---"
TIMEDATECTL_OUT=$(timedatectl show | tr -d '\r' | sed 's/\[?2004[lh]//g')
echo "$TIMEDATECTL_OUT"

NTP_ACTIVE=$(echo "$TIMEDATECTL_OUT" | grep '^NTP=' | cut -d= -f2 | tr -d '[:space:]')
NTP_SYNC=$(echo "$TIMEDATECTL_OUT"   | grep '^NTPSynchronized=' | cut -d= -f2 | tr -d '[:space:]')

echo "NTP            : ${NTP_ACTIVE:-unknown}"
echo "NTPSynchronized: ${NTP_SYNC:-unknown}"

# ------------------------------------------------------------
# 12. Retry block if not synchronized
#     (replaces: retry block with chronyc + attempt 2 + fail)
# ------------------------------------------------------------
if [ "${NTP_SYNC:-no}" != "yes" ]; then
  echo "--- [12] Not synchronized — retrying ---"

  chronyc -a sources
  chronyc -a 'burst 4/4'
  chronyc -a makestep

  echo "--- Waiting ${TIME_SYNC_RETRY_DELAY}s before retry verification ---"
  sleep "$TIME_SYNC_RETRY_DELAY"

  echo "--- Verifying NTP synchronization (attempt 2) ---"
  TIMEDATECTL_RETRY=$(timedatectl show | tr -d '\r' | sed 's/\[?2004[lh]//g')
  echo "$TIMEDATECTL_RETRY"

  NTP_ACTIVE_RETRY=$(echo "$TIMEDATECTL_RETRY" | grep '^NTP=' | cut -d= -f2 | tr -d '[:space:]')
  NTP_SYNC_RETRY=$(echo "$TIMEDATECTL_RETRY"   | grep '^NTPSynchronized=' | cut -d= -f2 | tr -d '[:space:]')

  echo "NTP (retry)            : ${NTP_ACTIVE_RETRY:-unknown}"
  echo "NTPSynchronized (retry): ${NTP_SYNC_RETRY:-unknown}"

  if [ "${NTP_SYNC_RETRY:-no}" != "yes" ]; then
    echo "[FAIL] NTP synchronization failed after retries"
    exit 1
  fi

  # Emit final result from retry values
  echo "RESULT_NTP=${NTP_ACTIVE_RETRY:-unknown}"
  echo "RESULT_SYNCED=${NTP_SYNC_RETRY:-no}"
else
  # Emit final result from attempt 1 values
  echo "RESULT_NTP=${NTP_ACTIVE:-unknown}"
  echo "RESULT_SYNCED=${NTP_SYNC:-no}"
fi

echo "--- Time sync completed successfully ---"
