#!/usr/bin/env bash
set -euo pipefail

tag="${BMUX_TAG:-swmob}"
repo="${BMUX_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
app="${BMUX_SWAPP:-$HOME/Library/Developer/Xcode/DerivedData/bmux-${tag}/Build/Products/Debug/bmux DEV ${tag}.app}"
port="${BMUX_PORT:-9300}"
port_range="${BMUX_PORT_RANGE:-10}"
port_end="${BMUX_PORT_END:-$((port + port_range - 1))}"
dev_origin="${BMUX_DEV_ORIGIN:-http://localhost:${port}}"
bin="$app/Contents/MacOS/bmux DEV"
tag_bundle_id="$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\.+//; s/\.+$//; s/\.+/./g')"
if [[ -z "$tag_bundle_id" ]]; then
  tag_bundle_id="agent"
fi

if [[ ! -x "$bin" ]]; then
  echo "missing tagged app binary: $bin" >&2
  exit 1
fi

exec env \
  BMUX_BUNDLE_ID="com.bmuxterm.app.debug.${tag_bundle_id}" \
  BMUX_SOCKET_ENABLE=1 \
  BMUX_SOCKET_MODE=allowAll \
  BMUX_SOCKET_PATH="/tmp/bmux-debug-${tag}.sock" \
  BMUXD_UNIX_PATH="$HOME/Library/Application Support/bmux/bmuxd-dev-${tag}.sock" \
  BMUX_DEBUG_LOG="/tmp/bmux-debug-${tag}.log" \
  BMUX_API_BASE_URL="$dev_origin" \
  BMUX_AUTH_WWW_ORIGIN="$dev_origin" \
  BMUX_VM_API_BASE_URL="$dev_origin" \
  BMUX_PORT="$port" \
  BMUX_PORT_RANGE="$port_range" \
  BMUX_PORT_END="$port_end" \
  PORT="$port" \
  BMUX_BUNDLED_CLI_PATH="$app/Contents/Resources/bin/bmux" \
  BMUX_SHELL_INTEGRATION_DIR="$app/Contents/Resources/shell-integration" \
  BMUX_REMOTE_DAEMON_ALLOW_LOCAL_BUILD=1 \
  BMUXTERM_REPO_ROOT="$repo" \
  "$bin"
