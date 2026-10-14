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

# --- 1. Static Ingress Schema Audit ---
REQUIRED_INGRESS_VARS=(
  "CLOUDFLARE_TUNNEL_TOKEN"
  "TAILSCALE_AUTHKEY"
  "TAILSCALE_HOSTNAME"
  "SECRET_KEY_BASE"
)

for var in "${REQUIRED_INGRESS_VARS[@]}"; do
  run_check "Schema key defined in .env.example: $var" grep -Eq "^${var}=" .env.example
  run_check "Schema key present in .env: $var" grep -Eq "^${var}=" .env
done

# --- 2. Live Orchestration & Graceful Container State ---
run_check "Launch updated compose stack" docker compose up -d

verify_no_crashloops() {
  local services=("tunnel" "tailscale")
  for s in "${services[@]}"; do
    if docker compose ps --services | grep -qx "$s"; then
      local status
      status=$(docker compose ps "$s" --format '{{.Status}}' || true)
      if echo "$status" | grep -qi "Restarting"; then
        echo "Service '$s' is in a crash loop (Status: $status)"
        return 1
      fi
    fi
  done
  return 0
}

sleep 3
run_check "Ingress services boot gracefully without crash looping" verify_no_crashloops

# --- 3. Internal Network Resolution & Reachability ---
verify_internal_mesh() {
  local rails_ready=false
  local jellyfin_ready=false

  # Poll up to 15 times (30 seconds) for internal endpoints to return 200
  for _ in {1..15}; do
    if ! $rails_ready; then
      if docker run --rm --network jolly_network curlimages/curl:latest -fsS -o /dev/null "http://jolly_rails:3000/up" 2>/dev/null; then
        rails_ready=true
      fi
    fi

    if ! $jellyfin_ready; then
      if docker run --rm --network jolly_network curlimages/curl:latest -fsS -o /dev/null "http://jolly_jellyfin:8096/health" 2>/dev/null; then
        jellyfin_ready=true
      fi
    fi

    if $rails_ready && $jellyfin_ready; then
      return 0
    fi
    sleep 2
  done

  echo "Internal bridge probe timeout: rails_ready=$rails_ready, jellyfin_ready=$jellyfin_ready"
  return 1
}

run_check "Internal bridge network resolves rails and jellyfin container DNS" verify_internal_mesh

# --- 4. Prior Milestone Regressions ---
run_check "Milestone 0.1 regression test" ./scripts/test-0.1.sh
run_check "Milestone 0.2 regression test" ./scripts/test-0.2.sh
run_check "Milestone 0.3 regression test" ./scripts/test-0.3.sh

# --- 5. Single Binary Verdict ---
echo "PASS"
exit 0
