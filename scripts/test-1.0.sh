#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_check() {
  local desc="$1"
  shift
  local err_file
  err_file="$(mktemp)"
  if ! "$@" > "$err_file" 2>&1; then
    echo "FAILED: $desc"
    echo "--- Error Details ---"
    cat "$err_file"
    rm -f "$err_file"
    exit 1
  fi
  rm -f "$err_file"
}

# --- 1. Production Artifacts Audit ---
run_check "Production installer script exists (install.sh)" test -f "install.sh"
run_check "Systemd unit template exists (jolly.service)" test -f "jolly.service"
run_check "Canonical compose specification exists" test -f "compose.yaml"
run_check "Canonical env schema exists (.env.example)" test -f ".env.example"

# --- 2. Script & Unit Syntax Validation ---
run_check "Installer script syntax check" bash -n "install.sh"

verify_systemd_unit() {
  grep -Eq '^ExecStart=' jolly.service || { echo "Missing ExecStart directive"; return 1; }
  grep -Eq '^ExecStop=' jolly.service || { echo "Missing ExecStop directive"; return 1; }
  grep -Eq '^Type=oneshot' jolly.service || { echo "Missing Type=oneshot directive"; return 1; }
  grep -Eq '^RemainAfterExit=yes' jolly.service || { echo "Missing RemainAfterExit directive"; return 1; }
  return 0
}
run_check "Systemd unit specification matches Contract 1.0" verify_systemd_unit

# --- Auto-Provision Valid Synthetic Test Media ---
provision_synthetic_media() {
  local movie_dir="data/media/movies/Test Synthetic (2026)"
  local target_file="$movie_dir/Test Synthetic (2026).mkv"
  local poster_file="$movie_dir/poster.jpg"

  mkdir -p "$movie_dir"

  # Generate a valid 5-second MKV test pattern using ffmpeg if missing or invalid
  if [[ ! -f "$target_file" ]] || ! ffprobe -v error "$target_file" &>/dev/null; then
    echo "==> Provisioning valid synthetic test video stream..."
    ffmpeg -y -f lavfi -i testsrc=duration=5:size=1280x720:rate=30 \
              -f lavfi -i anoisesrc=duration=5,aformat=channel_layouts=stereo \
              -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
              -c:a aac -b:a 128k \
              "$target_file" >/dev/null 2>&1
  fi

  # Ensure a valid dummy poster image exists so Skia doesn't throw invalid data errors
  if [[ ! -f "$poster_file" ]]; then
    # Generate a simple 200x300 solid color jpeg placeholder using ffmpeg
    ffmpeg -y -f lavfi -i color=c=blue:size=200x300 -vframes 1 "$poster_file" >/dev/null 2>&1
  fi
}

run_check "Synthetic test media provisioned and valid" provision_synthetic_media

# --- 3. Production Container Health Audit ---
run_check "Ensure orchestration stack is up" docker compose up -d

verify_stack_health() {
  local critical_services=("rails" "jellyfin" "tailscale")
  for s in "${critical_services[@]}"; do
    local status
    status=$(docker compose ps "$s" --format '{{.Status}}' || true)
    if ! echo "$status" | grep -qi "Up"; then
      echo "Critical service '$s' is not running (Status: $status)"
      return 1
    fi
  done
  return 0
}
run_check "Core services active and running" verify_stack_health

verify_appliance_services() {
  local services=("smbd" "wsdd")
  for svc in "${services[@]}"; do
    if ! systemctl is-active --quiet "$svc"; then
      echo "Required appliance service '$svc' is not active"
      return 1
    fi
  done
  return 0
}
run_check "Samba and WSD discovery daemons active" verify_appliance_services

# --- 4. Storage & Mount Permission Audit ---
verify_storage_rw() {
  local test_token="jolly_rw_test_$(date +%s)"

  echo "$test_token" > "data/rails/storage/.test_rw" || return 1
  rm -f "data/rails/storage/.test_rw"

  echo "$test_token" > "data/jellyfin/cache/.test_rw" || return 1
  rm -f "data/jellyfin/cache/.test_rw"

  echo "$test_token" > "data/media/movies/.test_rw" || return 1
  rm -f "data/media/movies/.test_rw"

  return 0
}
run_check "Host storage tree maintains read/write integrity" verify_storage_rw

# --- 5. Cumulative Milestone Regressions ---
echo "==> Running Cumulative Regression Gate (Milestones 0.1 - 0.5)..."
run_check "Milestone 0.1 (Container Runtime Baseline)" ./scripts/test-0.1.sh
run_check "Milestone 0.2 (Jellyfin Offline Media Layer)" ./scripts/test-0.2.sh
run_check "Milestone 0.3 (Rails 8 & Solid Stack Engine)" ./scripts/test-0.3.sh
run_check "Milestone 0.4 (Remote Mesh & Secure Ingress)" ./scripts/test-0.4.sh
run_check "Milestone 0.5 (Intel QSV Hardware Transcoding)" ./scripts/test-0.5.sh

# --- 6. Single Binary Verdict ---
echo "PASS"
exit 0
