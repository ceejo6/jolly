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

# 1. Environment & Config Parity
run_check "Environment file exists (.env)" test -f .env
run_check "Compose file exists (compose.yaml)" test -f compose.yaml

# 2. Container State Invariants
run_check "Start stack containers" docker compose up -d

# 3. Rails Healthcheck Polling
check_rails() {
  for _ in {1..15}; do
    if curl -fsS "http://localhost:3000/up" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

run_check "Rails health endpoint (port 3000)" check_rails

# 4. Jellyfin Healthcheck Polling
check_jellyfin() {
  for _ in {1..15}; do
    if curl -fsS "http://localhost:8096/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

run_check "Jellyfin health endpoint (port 8096)" check_jellyfin

echo "PASS"
exit 0
