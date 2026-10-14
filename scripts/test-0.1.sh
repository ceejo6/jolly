#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_check() {
  local desc="$1"
  shift
  if ! "$@" > /dev/null 2>&1; then
    echo "FAILED: $desc"
    exit 1
  fi
}

run_check "Filesystem tree" test -d data/rails/storage -a -d data/jellyfin/config -a -d data/jellyfin/cache -a -d data/media/movies -a -d data/media/tv
run_check "Gitignore data rules" grep -Eq '^data/?$' .gitignore
run_check "Gitignore env rules" grep -Eq '^\.env$' .gitignore
run_check "Env schema parity" bash -c 'for k in $(cut -d= -f1 .env.example | grep -v "^#" | grep -v "^$"); do grep -Eq "^${k}=" .env || exit 1; done'
run_check "Compose specification (no version key)" bash -c '! grep -Eq "^[[:space:]]*version:" compose.yaml'
run_check "Compose syntax valid" docker compose config --quiet

run_check "Stack startup" docker compose up -d

poll_http() {
  local url="$1"
  for _ in {1..20}; do
    [[ "$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)" == "200" ]] && return 0
    sleep 2
  done
  return 1
}

source .env
run_check "Rails health endpoint (port $RAILS_PORT)" poll_http "http://localhost:${RAILS_PORT}/up"
run_check "Jellyfin health endpoint (port $JELLYFIN_PORT)" poll_http "http://localhost:${JELLYFIN_PORT}/health"

echo "PASS"
exit 0
