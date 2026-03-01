#!/bin/bash
# install-patch-bundle.sh
# Runs on each edge node during the maintenance window
# Designed to be idempotent — safe to run multiple times

set -euo pipefail

INCOMING_DIR="/opt/patch-incoming"
REPO_DIR="/opt/patch-repo"
LOG_FILE="/var/log/patch-mgmt/$(date +%Y%m%d).log"
BUNDLE=$(ls ${INCOMING_DIR}/patch-bundle-*.tar.gz 2>/dev/null | sort | tail -1)

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "${LOG_FILE}"; }

# Pre-flight: confirm bundle exists
if [[ -z "${BUNDLE}" ]]; then
  log "ERROR: No bundle found in ${INCOMING_DIR}. Deferring."
  exit 1
fi

# Verify checksum
log "Verifying bundle integrity..."
sha256sum -c "${BUNDLE}.sha256" || { log "CHECKSUM FAILED. Aborting."; exit 2; }

# Verify GPG signature
gpg --verify "${BUNDLE}.asc" "${BUNDLE}" || { log "SIGNATURE FAILED. Aborting."; exit 3; }

# Unpack to repo directory
log "Unpacking bundle..."
mkdir -p "${REPO_DIR}"
tar -xzf "${BUNDLE}" -C "${REPO_DIR}"

# Install local repo config
cp "${REPO_DIR}/local.repo" /etc/yum.repos.d/local-patch.repo

# Run install — local repo only, no WAN access
log "Running package install..."
yum update -y \
  --disablerepo='*' \
  --enablerepo='local-patch' \
  --setopt=timeout=60

log "Patch complete. Reporting status..."

# Report outcome to central management
curl -sf -X POST https://patch-mgmt.internal/api/report \
  -H 'Content-Type: application/json' \
  -d "{\"host\": \"$(hostname)\", \"status\": \"success\", \"bundle\": \"${BUNDLE}\"}"

# Cleanup
rm -rf "${INCOMING_DIR}" "${REPO_DIR}"
