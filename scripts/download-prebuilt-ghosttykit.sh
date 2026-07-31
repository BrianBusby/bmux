#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -n "${GHOSTTY_SHA:-}" ]; then
  GHOSTTY_SHA="$GHOSTTY_SHA"
else
  if [ ! -d "$REPO_ROOT/ghostty" ] || ! git -C "$REPO_ROOT/ghostty" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Missing ghostty submodule. Run ./scripts/setup.sh or git submodule update --init --recursive first." >&2
    exit 1
  fi
  GHOSTTY_SHA="$(git -C "$REPO_ROOT/ghostty" rev-parse HEAD)"
fi

GHOSTTYKIT_CRASH_REPORT_SUBDIR="${GHOSTTYKIT_CRASH_REPORT_SUBDIR:-bmux/crash}"
GHOSTTYKIT_BUILD_FLAVOR="${GHOSTTYKIT_BUILD_FLAVOR:-crashsubdir-$(printf '%s' "$GHOSTTYKIT_CRASH_REPORT_SUBDIR" | tr '/=' '--')-v1}"
TAG="${GHOSTTYKIT_RELEASE_TAG:-xcframework-$GHOSTTY_SHA-$GHOSTTYKIT_BUILD_FLAVOR}"
ARCHIVE_NAME="${GHOSTTYKIT_ARCHIVE_NAME:-GhosttyKit.xcframework.tar.gz}"
OUTPUT_DIR="${GHOSTTYKIT_OUTPUT_DIR:-GhosttyKit.xcframework}"
CHECKSUMS_FILE="${GHOSTTYKIT_CHECKSUMS_FILE:-$SCRIPT_DIR/ghosttykit-checksums.txt}"
DOWNLOAD_RETRIES="${GHOSTTYKIT_DOWNLOAD_RETRIES:-30}"
DOWNLOAD_RETRY_DELAY="${GHOSTTYKIT_DOWNLOAD_RETRY_DELAY:-20}"
DOWNLOAD_CONNECT_TIMEOUT="${GHOSTTYKIT_DOWNLOAD_CONNECT_TIMEOUT:-10}"
DOWNLOAD_MAX_TIME="${GHOSTTYKIT_DOWNLOAD_MAX_TIME:-300}"
ARCHIVE_VALIDATOR="${GHOSTTYKIT_ARCHIVE_VALIDATOR:-$SCRIPT_DIR/validate-xcframework-archive.py}"

DOWNLOAD_CANDIDATES=()
if [ -n "${GHOSTTYKIT_URL:-}" ]; then
  DOWNLOAD_CANDIDATES+=("$GHOSTTYKIT_URL")
else
  DOWNLOAD_CANDIDATES+=("https://github.com/manaflow-ai/ghostty/releases/download/$TAG/$ARCHIVE_NAME")
  LEGACY_CMUX_TAG="xcframework-$GHOSTTY_SHA-crashsubdir-cmux-crash-v1"
  if [ "$GHOSTTYKIT_CRASH_REPORT_SUBDIR" = "bmux/crash" ] \
    && [ "${GHOSTTYKIT_ALLOW_LEGACY_CMUX_PREBUILT:-1}" = "1" ] \
    && [ "$LEGACY_CMUX_TAG" != "$TAG" ]; then
    DOWNLOAD_CANDIDATES+=("https://github.com/manaflow-ai/ghostty/releases/download/$LEGACY_CMUX_TAG/$ARCHIVE_NAME")
  fi
fi

if [ ! -f "$CHECKSUMS_FILE" ]; then
  echo "Missing checksum file: $CHECKSUMS_FILE" >&2
  exit 1
fi

EXPECTED_SHA256="$(
  awk -v sha="$GHOSTTY_SHA" '
    $1 == sha {
      print $2
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$CHECKSUMS_FILE" || true
)"

if [ -z "$EXPECTED_SHA256" ]; then
  echo "Missing pinned GhosttyKit checksum for ghostty $GHOSTTY_SHA in $CHECKSUMS_FILE" >&2
  exit 1
fi

echo "Downloading $ARCHIVE_NAME for ghostty $GHOSTTY_SHA"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ghosttykit-download.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
ARCHIVE_BASENAME="$(basename "$ARCHIVE_NAME")"
ARCHIVE_PATH="$TMP_DIR/$ARCHIVE_BASENAME"
EXTRACT_DIR="$TMP_DIR/extract"
mkdir -p "$EXTRACT_DIR"

DOWNLOAD_URL=""
for CANDIDATE_URL in "${DOWNLOAD_CANDIDATES[@]}"; do
  echo "Checking GhosttyKit archive URL: $CANDIDATE_URL"
  if curl --fail --silent --show-error --location --head \
    --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" \
    --max-time 60 \
    -o /dev/null \
    "$CANDIDATE_URL" >/dev/null; then
    DOWNLOAD_URL="$CANDIDATE_URL"
    break
  fi
  echo "GhosttyKit archive not available at $CANDIDATE_URL"
done

if [ -z "$DOWNLOAD_URL" ]; then
  echo "No pre-built GhosttyKit archive found for ghostty $GHOSTTY_SHA" >&2
  exit 1
fi

curl --fail --show-error --location \
  --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" \
  --max-time "$DOWNLOAD_MAX_TIME" \
  --retry "$DOWNLOAD_RETRIES" \
  --retry-delay "$DOWNLOAD_RETRY_DELAY" \
  --retry-all-errors \
  -o "$ARCHIVE_PATH" \
  "$DOWNLOAD_URL"

ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "$ARCHIVE_NAME checksum mismatch" >&2
  echo "Expected: $EXPECTED_SHA256" >&2
  echo "Actual:   $ACTUAL_SHA256" >&2
  exit 1
fi

python3 "$ARCHIVE_VALIDATOR" "$ARCHIVE_PATH"
mkdir -p "$(dirname "$OUTPUT_DIR")"
tar --no-same-owner -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"
rm -rf "$OUTPUT_DIR"
mv "$EXTRACT_DIR/GhosttyKit.xcframework" "$OUTPUT_DIR"
test -d "$OUTPUT_DIR"

echo "Verified and extracted $OUTPUT_DIR"
