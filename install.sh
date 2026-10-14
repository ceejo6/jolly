#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# PROJECT JOLLY: UNIFIED BARE-METAL PRODUCTION INSTALLER (v1.0)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
   echo "Error: install.sh must be run as root (sudo ./install.sh)" >&2
   exit 1
fi

TARGET_DIR="/opt/jolly"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Step 1: Installing Host Prerequisites & Docker Engine..."
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release

# Install Docker official repository if missing
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "==> Step 2: Provisioning Target Directory & Storage Hierarchy..."
mkdir -p "$TARGET_DIR"
if [[ "$CURRENT_DIR" != "$TARGET_DIR" ]]; then
  cp -a "$CURRENT_DIR/." "$TARGET_DIR/"
fi

mkdir -p "$TARGET_DIR/data/rails/storage" \
         "$TARGET_DIR/data/jellyfin/config" \
         "$TARGET_DIR/data/jellyfin/cache" \
         "$TARGET_DIR/data/media/movies" \
         "$TARGET_DIR/data/media/tv" \
         "$TARGET_DIR/data/tailscale"

chmod -R 777 "$TARGET_DIR/data"

echo "==> Step 3: Registering and Enabling Systemd Service..."
cp "$TARGET_DIR/jolly.service" /etc/systemd/system/jolly.service
sed -i "s|WorkingDirectory=.*|WorkingDirectory=$TARGET_DIR|g" /etc/systemd/system/jolly.service

systemctl daemon-reload
systemctl enable jolly.service

echo "==> Step 4: Bootstrapping Container Stack..."
cd "$TARGET_DIR"
docker compose build
systemctl restart jolly.service

echo "==> Step 5: Running Master Acceptance Harness (v1.0)..."
"$TARGET_DIR/scripts/test-1.0.sh"

echo "=============================================================================="
echo "Project Jolly v1.0 Production Appliance deployed successfully!"
echo "Server will now automatically boot on physical host power-on."
echo "=============================================================================="
