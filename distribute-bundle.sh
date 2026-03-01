#!/bin/bash
# distribute-bundle.sh
# Distributes patch bundle to edge nodes with rate limiting

BUNDLE_FILE="$1"
LOCATIONS_FILE="/etc/patch-mgmt/locations.txt"  # list of edge node hostnames
DEST_PATH="/opt/patch-incoming/"
MAX_BW_KBPS=2048  # 2 Mbps cap per transfer
MAX_PARALLEL=20   # transfer to 20 locations at once

transfer_to_node() {
  local host="$1"
  rsync -avz --bwlimit=${MAX_BW_KBPS} \
    --timeout=300 \
    --partial --progress \
    "${BUNDLE_FILE}" \
    "${BUNDLE_FILE}.sha256" \
    "${BUNDLE_FILE}.asc" \
    "deploy@${host}:${DEST_PATH}" \
    && echo "[OK] ${host}" \
    || echo "[FAIL] ${host}"
}

export -f transfer_to_node
export BUNDLE_FILE MAX_BW_KBPS DEST_PATH

# Parallel transfer with concurrency cap
cat "${LOCATIONS_FILE}" | \
  xargs -P ${MAX_PARALLEL} -I{} bash -c 'transfer_to_node {}'
