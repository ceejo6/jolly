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

run_check "Compose stack running" docker compose up -d

HAS_DRI=false
if [[ -e "/dev/dri/renderD128" ]] || [[ -d "/dev/dri" ]]; then
  HAS_DRI=true
fi

test_transcode_pipeline() {
  local container="jolly_jellyfin"

  docker exec "$container" test -x /usr/lib/jellyfin-ffmpeg/ffmpeg || {
    echo "Error: /usr/lib/jellyfin-ffmpeg/ffmpeg not executable inside container"
    return 1
  }

  if $HAS_DRI && docker exec "$container" test -e /dev/dri/renderD128 2>/dev/null; then
    docker exec "$container" /usr/lib/jellyfin-ffmpeg/ffmpeg -y \
      -init_hw_device vaapi=va:/dev/dri/renderD128 \
      -filter_hw_device va \
      -f lavfi -i testsrc=duration=3:size=1920x1080:rate=30 \
      -vf 'format=nv12,hwupload' \
      -c:v h264_vaapi -b:v 3M \
      -f mp4 /cache/test_hw_transcode.mp4 >/dev/null 2>&1 || {
        echo "Hardware VAAPI/QSV probe failed; checking permissions on /dev/dri"
        return 1
      }
    docker exec "$container" test -s /cache/test_hw_transcode.mp4 || return 1
    docker exec "$container" rm -f /cache/test_hw_transcode.mp4
  else
    docker exec "$container" /usr/lib/jellyfin-ffmpeg/ffmpeg -y \
      -f lavfi -i testsrc=duration=2:size=1280x720:rate=24 \
      -c:v libx264 -preset ultrafast -b:v 1M \
      -f mp4 /cache/test_sw_transcode.mp4 >/dev/null 2>&1 || {
        echo "Software transcode fallback failed"
        return 1
      }
    docker exec "$container" test -s /cache/test_sw_transcode.mp4 || return 1
    docker exec "$container" rm -f /cache/test_sw_transcode.mp4
  fi

  return 0
}

run_check "Jellyfin transcode execution (hardware or graceful software fallback)" test_transcode_pipeline

run_check "Milestone 0.1 regression test" ./scripts/test-0.1.sh
run_check "Milestone 0.2 regression test" ./scripts/test-0.2.sh
run_check "Milestone 0.3 regression test" ./scripts/test-0.3.sh
run_check "Milestone 0.4 regression test" ./scripts/test-0.4.sh

echo "PASS"
exit 0
