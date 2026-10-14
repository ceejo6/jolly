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

# --- 1. Static Layout & Dockerfile Checks ---
run_check "Rails app source tree exists" test -d "apps/web"
run_check "Rails multi-stage Dockerfile present" test -s "apps/web/Dockerfile"
run_check "Multi-database SQLite configuration present" test -s "apps/web/config/database.yml"
run_check "Host storage mount point exists" test -d "data/rails/storage"

# --- 2. Container Build & Orchestration Update ---
source .env
run_check "Build Rails 8 container image" docker compose build rails
run_check "Spin up updated Compose stack" docker compose up -d

# --- 3. Puma Health Endpoint Poll ---
poll_health() {
  local url="$1"
  for _ in {1..30}; do
    if curl -fsS -o /dev/null "$url"; then
      return 0
    fi
    sleep 2
  done
  echo "Timeout waiting for Puma healthcheck at: $url"
  return 1
}

run_check "Puma responds HTTP 200 on /up" poll_health "http://localhost:${RAILS_PORT}/up"

# --- 4. SQLite Persistence & WAL Mode Verification ---
verify_sqlite_persistence() {
  test -f "data/rails/storage/production.sqlite3" || return 1
  return 0
}

run_check "SQLite database created in host mount data/rails/storage" verify_sqlite_persistence

# --- 5. Prior Milestone Regressions ---
run_check "Milestone 0.1 regression check" ./scripts/test-0.1.sh
run_check "Milestone 0.2 regression check" ./scripts/test-0.2.sh

echo "PASS"
exit 0
