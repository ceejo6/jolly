#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# PROJECT JOLLY: UNIFIED ZERO-TOUCH APPLIANCE BOOTSTRAP (v1.0.1)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
   echo "Error: install.sh must be run as root (sudo ./install.sh)" >&2
   exit 1
fi

TARGET_DIR="/opt/jolly"
REPO_URL="https://github.com/ceejo6/jolly.git"

echo "==> Step 1: Installing Base System Packages..."
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release git

# Install Docker Engine and Compose Plugin if missing
if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker Engine & Compose plugin..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "==> Step 2: Preparing Appliance Directory..."
if [[ ! -d "$TARGET_DIR/.git" ]]; then
  echo "==> Cloning Project Jolly into $TARGET_DIR..."
  git clone "$REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"

# Ensure environment file exists with clean defaults
if [[ ! -f "$TARGET_DIR/.env" ]]; then
  echo "==> Seeding initial configuration (.env)..."
  cp "$TARGET_DIR/.env.example" "$TARGET_DIR/.env"
fi

# Provision host storage mounts with non-restrictive container permissions
mkdir -p "$TARGET_DIR/data/rails/storage" \
         "$TARGET_DIR/data/jellyfin/config" \
         "$TARGET_DIR/data/jellyfin/cache" \
         "$TARGET_DIR/data/media/movies" \
         "$TARGET_DIR/data/media/tv" \
         "$TARGET_DIR/data/tailscale"

chmod -R 777 "$TARGET_DIR/data"

echo "==> Step 3: Configuring OS Daemon (systemd)..."
cp "$TARGET_DIR/jolly.service" /etc/systemd/system/jolly.service
sed -i "s|WorkingDirectory=.*|WorkingDirectory=$TARGET_DIR|g" /etc/systemd/system/jolly.service

systemctl daemon-reload
systemctl enable jolly.service

echo "==> Step 4: Building & Launching Appliance..."
docker compose build
systemctl restart jolly.service

echo "==> Step 5: Executing Verification Acceptance Gate..."
"$TARGET_DIR/scripts/test-1.0.sh"

SERVER_IP=$(hostname -I | awk '{print $1}')
echo "=============================================================================="
echo "Project Jolly Appliance deployed successfully!"
echo "Server will automatically start on physical host power-on."
echo ""
echo "Access your media server right now by visiting:"
echo "http://${SERVER_IP}:8096"
echo "=============================================================================="
