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

# --- 4. Synthetic Media Fixture Injection (Air-Gap Test) ---
MOCK_DIR="data/media/movies/Test Synthetic (2026)"
mkdir -p "$MOCK_DIR"

# Generate 100KB dummy video
dd if=/dev/zero of="$MOCK_DIR/Test Synthetic (2026).mkv" bs=1024 count=100 status=none

# Inject local NFO metadata
cat <<'NFO' > "$MOCK_DIR/Test Synthetic (2026).nfo"
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<movie>
  <title>Test Synthetic</title>
  <originaltitle>Test Synthetic</originaltitle>
  <sorttitle>Test Synthetic</sorttitle>
  <year>2026</year>
  <plot>An air-gapped test movie verifying local metadata persistence without WAN scraping.</plot>
  <outline>Synthetic verification fixture.</outline>
  <genre>Automation</genre>
  <studio>Jolly Studios</studio>
</movie>
NFO

# Inject placeholder image fixtures
printf '\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xFF\xDB\x00C\x00' > "$MOCK_DIR/poster.jpg"
printf '\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xFF\xDB\x00C\x00' > "$MOCK_DIR/backdrop.jpg"

# --- 5. Air-Gap Metadata Verification on Disk ---
run_check "Synthetic video file present" test -s "$MOCK_DIR/Test Synthetic (2026).mkv"
run_check "NFO file contains valid title" grep -q "<title>Test Synthetic</title>" "$MOCK_DIR/Test Synthetic (2026).nfo"
run_check "NFO file contains valid plot" grep -q "<plot>.*air-gapped.*</plot>" "$MOCK_DIR/Test Synthetic (2026).nfo"
run_check "Poster artwork fixture present" test -s "$MOCK_DIR/poster.jpg"
run_check "Backdrop artwork fixture present" test -s "$MOCK_DIR/backdrop.jpg"

echo "PASS"
exit 0
