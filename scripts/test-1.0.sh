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
