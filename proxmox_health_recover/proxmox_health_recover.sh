#!/usr/bin/env bash
set -euo pipefail

# Required env vars:
# PROXMOX_HOST, PROXMOX_HEALTH_URL, PROXMOX_SSH_USER, PROXMOX_SSH_HOST
# Optional:
# REBOOT_COOLDOWN_SEC (default 1800), CURL_TIMEOUT (default 5)

COOLDOWN="${REBOOT_COOLDOWN_SEC:-1800}"
TIMEOUT="${CURL_TIMEOUT:-5}"
LOCK_FILE="${HOME}/.agenta/proxmox-reboot.lock"

mkdir -p "$(dirname "$LOCK_FILE")"

health_ok() {
  curl -fsS --max-time "$TIMEOUT" "$PROXMOX_HEALTH_URL" >/dev/null 2>&1
}

# 3 checks to reduce false positive
if health_ok && health_ok && health_ok; then
  echo "OK: $PROXMOX_HOST healthy"
  exit 0
fi

now="$(date +%s)"
if [[ -f "$LOCK_FILE" ]]; then
  last="$(cat "$LOCK_FILE" || echo 0)"
  if (( now - last < COOLDOWN )); then
    echo "WARN: unhealthy but cooldown active, skip reboot"
    exit 0
  fi
fi

# last confirmation before reboot
if health_ok; then
  echo "OK: recovered before reboot"
  exit 0
fi

echo "$now" > "$LOCK_FILE"

ssh -o BatchMode=yes -o ConnectTimeout=8 \
  "${PROXMOX_SSH_USER}@${PROXMOX_SSH_HOST}" \
  "sudo /sbin/reboot" && echo "ACTION: reboot sent" || echo "ERROR: reboot failed"

