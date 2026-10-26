#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# PROJECT JOLLY: UNIFIED ZERO-TOUCH APPLIANCE BOOTSTRAP (v1.0.3)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
   echo "Error: install.sh must be run as root (sudo ./install.sh)" >&2
   exit 1
fi

TARGET_DIR="/opt/jolly"
REPO_URL="https://github.com/ceejo6/jolly.git"

echo "==> Step 1: Installing Base System Packages..."
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release git samba wsdd ufw ffmpeg
# Ensure firewall allows SMB and WSD discovery if UFW is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  echo "==> Opening firewall ports for SMB and WSD..."
  ufw allow 445/tcp
  ufw allow 139/tcp
  ufw allow 3702/udp
  ufw allow 8096/tcp
fi

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

echo "==> Step 2: Preparing Appliance Directory & Storage Hierarchy..."
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

# Provision host storage mounts
mkdir -p "$TARGET_DIR/data/rails/storage" \
         "$TARGET_DIR/data/jellyfin/config" \
         "$TARGET_DIR/data/jellyfin/cache" \
         "$TARGET_DIR/data/media/movies" \
         "$TARGET_DIR/data/media/tv" \
         "$TARGET_DIR/data/tailscale"

chmod -R 777 "$TARGET_DIR/data"

# --- Auto-Provision Valid Synthetic Test Media ---
echo "==> Provisioning valid synthetic test media for Jolly..."
MOVIE_DIR="data/media/movies/Test Synthetic (2026)"
mkdir -p "$MOVIE_DIR"

# Generate a valid streamable 5-second MKV test file if missing or corrupted
if [[ ! -f "$MOVIE_DIR/Test Synthetic (2026).mkv" ]] || ! ffprobe -v error "$MOVIE_DIR/Test Synthetic (2026).mkv" &>/dev/null; then
  ffmpeg -y -f lavfi -i testsrc=duration=5:size=1280x720:rate=30 \
            -f lavfi -i anoisesrc=duration=5,aformat=channel_layouts=stereo \
            -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
            -c:a aac -b:a 128k \
            "$MOVIE_DIR/Test Synthetic (2026).mkv" >/dev/null 2>&1
fi

# Ensure clean artwork assets exist so Skia doesn't throw incomplete input warnings
if [[ ! -f "$MOVIE_DIR/poster.jpg" ]]; then
  ffmpeg -y -f lavfi -i color=c=blue:size=200x300 -vframes 1 "$MOVIE_DIR/poster.jpg" >/dev/null 2>&1
fi

if [[ ! -f "$MOVIE_DIR/backdrop.jpg" ]]; then
  ffmpeg -y -f lavfi -i color=c=black:size=1280x720 -vframes 1 "$MOVIE_DIR/backdrop.jpg" >/dev/null 2>&1
fi

# Configure Native Windows Network Share (Samba) with Secure Authentication
SAMBA_USER="${SUDO_USER:-jollyadmin}"
SAMBA_PASS="jollysecure123" # Or dynamically generated / prompted

echo "==> Configuring Windows Network Share (Samba) for user: $SAMBA_USER..."

# Ensure system user exists
if ! id "$SAMBA_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$SAMBA_USER"
fi

# Set Samba password non-interactively for zero-touch deployment
(echo "$SAMBA_PASS"; echo "$SAMBA_PASS") | smbpasswd -s -a "$SAMBA_USER"
smbpasswd -e "$SAMBA_USER"

# Write robust smb.conf share definition
if ! grep -q "\[JollyMedia\]" /etc/samba/smb.conf; then
  cat <<SMB >> /etc/samba/smb.conf

[JollyMedia]
   path = /opt/jolly/data/media
   browseable = yes
   read only = no
   guest ok = no
   valid users = $SAMBA_USER
   create mask = 0777
   directory mask = 0777
   force user = $SAMBA_USER
SMB
  systemctl restart smbd
  systemctl enable smbd --now
  systemctl enable wsdd --now
fi

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
echo "1. Access your web streaming dashboard:"
echo "   http://${SERVER_IP}:8096"
echo ""
echo "2. Add movies and TV shows from any Windows PC (File Explorer / Run):"
echo "   \\\\${SERVER_IP}\\JollyMedia"
echo "=============================================================================="
