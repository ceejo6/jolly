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

# --- 1. Static Media Directory Checks ---
run_check "Media movies root exists" test -d "data/media/movies"
run_check "Media TV root exists" test -d "data/media/tv"

# --- 2. Live Service Status Check ---
source .env
poll_http() {
  local url="$1"
  for _ in {1..20}; do
    local code
    curl -fsS -o /dev/null "$url" && return 0
    
    sleep 1
  done
  echo "Endpoint did not return 200 within timeout: $url (Last code:$code)"
  return 1
}

run_check "Jellyfin HTTP service reachable" poll_http "http://localhost:${JELLYFIN_PORT}/health"

# --- 3. Discovery Port Mapping Check ---
run_check "Discovery UDP 7359 port mapped" docker compose port --protocol udp jellyfin "${JELLYFIN_DISCOVERY_PORT}"

# --- 4. Air-Gap Metadata Verification on Disk ---
run_check "Synthetic video file present" test -s "$MOCK_DIR/Test Synthetic (2026).mkv"
run_check "NFO file contains valid title" grep -q "<title>Test Synthetic</title>" "$MOCK_DIR/Test Synthetic (2026).nfo"
run_check "NFO file contains valid plot" grep -q "<plot>.*air-gapped.*</plot>" "$MOCK_DIR/Test Synthetic (2026).nfo"
run_check "Poster artwork fixture present" test -s "$MOCK_DIR/poster.jpg"
run_check "Backdrop artwork fixture present" test -s "$MOCK_DIR/backdrop.jpg"

echo "PASS"
exit 0
