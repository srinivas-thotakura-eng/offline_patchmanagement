#!/bin/bash
# build-patch-bundle.sh
# Produces a self-contained, signed patch bundle for edge distribution

set -euo pipefail

BUNDLE_VERSION="$(date +%Y%m%d)-${BUILD_ID:-local}"
STAGING_DIR="/tmp/patch-staging-${BUNDLE_VERSION}"
OUTPUT_DIR="/opt/patch-bundles"
GPG_KEY_ID="your-signing-key-id"

# Create staging area
mkdir -p "${STAGING_DIR}/packages"

# Download all available updates for target OS
echo "[+] Downloading packages..."
repotrack --download_path="${STAGING_DIR}/packages" \
  --repofrompath="base,/etc/yum.repos.d/" \
  $(yum check-update -q | awk '{print $1}' | grep -v '^$')

# Create local RPM repository metadata
echo "[+] Building repository metadata..."
createrepo_c --workers=4 "${STAGING_DIR}/packages"

# Write repo config file (used by edge node at install time)
cat > "${STAGING_DIR}/local.repo" << EOF
[local-patch]
name=Local Patch Repository ${BUNDLE_VERSION}
baseurl=file:///opt/patch-repo
enabled=1
gpgcheck=0
priority=1
EOF

# Bundle everything
echo "[+] Compressing bundle..."
tar -czf "${OUTPUT_DIR}/patch-bundle-${BUNDLE_VERSION}.tar.gz" \
  -C "${STAGING_DIR}" .

# Generate checksum and sign
sha256sum "${OUTPUT_DIR}/patch-bundle-${BUNDLE_VERSION}.tar.gz" \
  > "${OUTPUT_DIR}/patch-bundle-${BUNDLE_VERSION}.sha256"

gpg --batch --yes --armor \
  --local-user "${GPG_KEY_ID}" \
  --detach-sign "${OUTPUT_DIR}/patch-bundle-${BUNDLE_VERSION}.tar.gz"

echo "[+] Bundle ready: patch-bundle-${BUNDLE_VERSION}.tar.gz"
