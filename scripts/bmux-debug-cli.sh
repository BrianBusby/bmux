#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BMUX_TAG:-}" ]]; then
  cat >&2 <<'EOF'
BMUX_TAG is required.

Usage:
  BMUX_TAG=<tag> scripts/bmux-debug-cli.sh <bmux-command> [args...]

Example:
  BMUX_TAG=codext scripts/bmux-debug-cli.sh list-workspaces
EOF
  exit 2
fi

if [[ ! "$BMUX_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid BMUX_TAG: $BMUX_TAG" >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: BMUX_TAG=$BMUX_TAG scripts/bmux-debug-cli.sh <bmux-command> [args...]" >&2
  exit 2
fi

sanitize_bundle() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\.+//; s/\.+$//; s/\.+/./g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

sanitize_path() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

tag_slug="$(sanitize_path "$BMUX_TAG")"
tag_bundle_id="$(sanitize_bundle "$BMUX_TAG")"

socket_path="/tmp/bmux-debug-${tag_slug}.sock"
if [[ ! -S "$socket_path" ]]; then
  cat >&2 <<EOF
Tagged bmux socket not found:
  $socket_path

Launch the tagged app first:
  ./scripts/reload.sh --tag $BMUX_TAG --launch
EOF
  exit 1
fi

cli_path="${HOME}/Library/Developer/Xcode/DerivedData/bmux-${tag_slug}/Build/Products/Debug/bmux DEV ${tag_slug}.app/Contents/Resources/bin/bmux"
if [[ ! -x "$cli_path" ]]; then
  cat >&2 <<EOF
Tagged bmux CLI not found:
  $cli_path

Build the tagged app first:
  ./scripts/reload.sh --tag $BMUX_TAG
EOF
  exit 1
fi

unset BMUX_SOCKET
unset BMUX_SOCKET_PASSWORD
unset BMUX_WORKSPACE_ID
unset BMUX_SURFACE_ID
unset BMUX_TAB_ID
unset BMUX_PANEL_ID
unset BMUXD_UNIX_PATH
unset BMUX_DEBUG_LOG
export BMUX_SOCKET_PATH="$socket_path"
export BMUX_TAG="$tag_slug"
export BMUX_BUNDLE_ID="com.bmuxterm.app.debug.${tag_bundle_id}"
export BMUX_BUNDLED_CLI_PATH="$cli_path"
exec "$cli_path" "$@"
