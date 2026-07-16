#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ZIG_REQUIRED="${ZIG_REQUIRED:-0.15.2}"

cd "$PROJECT_DIR"

hash_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
  fi
}

hash_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    sha256sum "$path" | awk '{print $1}'
  fi
}

lookup_pinned_ghosttykit_sha256() {
  local ghostty_sha="$1"
  local checksums_file="$2"
  awk -v sha="$ghostty_sha" '
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
  ' "$checksums_file"
}

validate_bridge_header() {
  local path="$1"
  python3 - "$path" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
required = '#include "ghostty/include/ghostty.h"'
if required not in text:
    raise SystemExit(1)
PY
}

zig_has_required_version() {
  local zig_path="$1"
  [[ -x "$zig_path" ]] || return 1
  [[ "$("$zig_path" version 2>/dev/null || true)" == "$ZIG_REQUIRED" ]]
}

select_zig() {
  if [[ -n "${BMUX_ZIG:-}" ]]; then
    if [[ ! -x "$BMUX_ZIG" ]]; then
      echo "error: BMUX_ZIG is not executable: $BMUX_ZIG" >&2
      return 1
    fi
    if ! zig_has_required_version "$BMUX_ZIG"; then
      echo "error: BMUX_ZIG must be zig ${ZIG_REQUIRED}: $BMUX_ZIG" >&2
      return 1
    fi
    echo "$BMUX_ZIG"
    return 0
  fi

  local user_zig_root="${BMUX_ZIG_ROOT:-${HOME:-}/.local/share/bmux/zig}"
  local path_zig=""
  path_zig="$(command -v zig 2>/dev/null || true)"
  local -a candidates=(
    "$user_zig_root/zig-aarch64-macos-${ZIG_REQUIRED}/zig"
    "$user_zig_root/zig-x86_64-macos-${ZIG_REQUIRED}/zig"
  )
  [[ -n "$path_zig" ]] && candidates+=("$path_zig")
  candidates+=("/opt/homebrew/bin/zig" "/usr/local/bin/zig")

  local candidate=""
  local canonical=""
  local seen=" "
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    canonical="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    [[ "$seen" == *" $canonical "* ]] && continue
    seen="${seen}${canonical} "
    if zig_has_required_version "$canonical"; then
      echo "$canonical"
      return 0
    fi
  done

  echo "error: zig ${ZIG_REQUIRED} is required to build GhosttyKit.xcframework" >&2
  return 1
}

if [[ ! -d "$PROJECT_DIR/ghostty" ]]; then
  echo "error: ghostty submodule is missing. Run ./scripts/setup.sh first." >&2
  exit 1
fi

ZIG_BIN="$(select_zig)"
echo "==> Using zig $("$ZIG_BIN" version) at $ZIG_BIN"

if [[ ! -f "$PROJECT_DIR/ghostty/include/ghostty.h" ]]; then
  echo "error: ghostty/include/ghostty.h is missing. Run ./scripts/setup.sh first." >&2
  exit 1
fi

if ! validate_bridge_header "$PROJECT_DIR/ghostty.h"; then
  echo "error: ghostty.h no longer points at ghostty/include/ghostty.h." >&2
  echo "Restore the bridge header so Xcode uses Ghostty's canonical C API." >&2
  exit 1
fi

GHOSTTY_SHA="$(git -C ghostty rev-parse HEAD)"
GHOSTTYKIT_CRASH_REPORT_SUBDIR="${BMUX_GHOSTTYKIT_CRASH_REPORT_SUBDIR:-bmux/crash}"
GHOSTTYKIT_BUILD_FLAVOR="crashsubdir-$(printf '%s' "$GHOSTTYKIT_CRASH_REPORT_SUBDIR" | tr '/=' '--')-v1"
GHOSTTY_CLEAN_KEY="${GHOSTTY_SHA}-${GHOSTTYKIT_BUILD_FLAVOR}"
GHOSTTY_KEY="$GHOSTTY_CLEAN_KEY"
UNTRACKED_FILES="$(
  git -C ghostty ls-files --others --exclude-standard |
    grep -v '^zig-pkg/' ||
    true
)"
if ! git -C ghostty diff --quiet --ignore-submodules=all HEAD -- || [[ -n "$UNTRACKED_FILES" ]]; then
  DIRTY_HASH="$(
    {
      printf 'head=%s\n' "$GHOSTTY_SHA"
      git -C ghostty diff --binary HEAD -- .
      if [[ -n "$UNTRACKED_FILES" ]]; then
        printf '\n--untracked--\n'
        while IFS= read -r path; do
          [[ -n "$path" ]] || continue
          printf 'path=%s\n' "$path"
          hash_file "$PROJECT_DIR/ghostty/$path"
        done <<< "$UNTRACKED_FILES"
      fi
    } | hash_stdin
  )"
  GHOSTTY_KEY="${GHOSTTY_CLEAN_KEY}-dirty-${DIRTY_HASH}"
fi

CACHE_ROOT="${BMUX_GHOSTTYKIT_CACHE_DIR:-$HOME/.cache/bmux/ghosttykit}"
LOCAL_XCFRAMEWORK="$PROJECT_DIR/ghostty/macos/GhosttyKit.xcframework"
LOCAL_KEY_STAMP="$LOCAL_XCFRAMEWORK/.ghostty_state_key"
LEGACY_LOCAL_SHA_STAMP="$LOCAL_XCFRAMEWORK/.ghostty_sha"
GHOSTTYKIT_CHECKSUMS_FILE="${BMUX_GHOSTTYKIT_CHECKSUMS_FILE:-$SCRIPT_DIR/ghosttykit-checksums.txt}"
GHOSTTYKIT_ARCHIVE_VALIDATOR="${BMUX_GHOSTTYKIT_ARCHIVE_VALIDATOR:-$SCRIPT_DIR/validate-xcframework-archive.py}"

set_ghostty_cache_key() {
  GHOSTTY_KEY="$1"
  CACHE_DIR="$CACHE_ROOT/$GHOSTTY_KEY"
  CACHE_XCFRAMEWORK="$CACHE_DIR/GhosttyKit.xcframework"
}

set_ghostty_cache_key "$GHOSTTY_KEY"
LOCK_DIR="$CACHE_ROOT/$GHOSTTY_KEY.lock"

mkdir -p "$CACHE_ROOT"

echo "==> Ghostty build key: $GHOSTTY_KEY"

LOCK_TIMEOUT=300
LOCK_START=$SECONDS
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  if (( SECONDS - LOCK_START > LOCK_TIMEOUT )); then
    echo "==> Lock stale (>${LOCK_TIMEOUT}s), removing and retrying..."
    rmdir "$LOCK_DIR" 2>/dev/null || rm -rf "$LOCK_DIR"
    continue
  fi
  echo "==> Waiting for GhosttyKit cache lock for $GHOSTTY_KEY..."
  sleep 1
done
trap 'rmdir "$LOCK_DIR" >/dev/null 2>&1 || true' EXIT

try_fetch_prebuilt_xcframework() {
  # Only attempt when Ghostty submodule is clean — dirty trees won't match any
  # published release. Opt-out via BMUX_GHOSTTYKIT_NO_PREBUILT=1.
  #
  # Trust model: only install prebuilt artifacts whose SHA256 is pinned in the
  # reviewed checksum manifest for the current ghostty submodule commit.
  # Unpinned or mismatched artifacts fall back to a local ReleaseFast build.
  if [[ "$GHOSTTY_KEY" != "$GHOSTTY_CLEAN_KEY" ]]; then
    return 1
  fi
  if [[ "${BMUX_GHOSTTYKIT_NO_PREBUILT:-0}" == "1" ]]; then
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    return 1
  fi

  if [[ ! -f "$GHOSTTYKIT_CHECKSUMS_FILE" ]]; then
    echo "==> Missing GhosttyKit checksum manifest; falling back to local build." >&2
    return 1
  fi

  local expected_sha
  if ! expected_sha="$(lookup_pinned_ghosttykit_sha256 "$GHOSTTY_SHA" "$GHOSTTYKIT_CHECKSUMS_FILE" 2>/dev/null)"; then
    echo "==> No pinned GhosttyKit checksum for ${GHOSTTY_SHA:0:12}; falling back to local build." >&2
    return 1
  fi

  local -a candidate_keys=("$GHOSTTY_CLEAN_KEY")
  local legacy_cmux_key="${GHOSTTY_SHA}-crashsubdir-cmux-crash-v1"
  # Compatibility bridge for SHAs whose prebuilt artifact was published before
  # the project crash directory was renamed from cmux/crash to bmux/crash.
  if [[ "$GHOSTTYKIT_CRASH_REPORT_SUBDIR" == "bmux/crash"
        && "${BMUX_GHOSTTYKIT_ALLOW_LEGACY_CMUX_PREBUILT:-1}" == "1"
        && "$legacy_cmux_key" != "$GHOSTTY_CLEAN_KEY" ]]; then
    candidate_keys+=("$legacy_cmux_key")
  fi

  local candidate_key candidate_cache_xcframework url tmp_dir tmp_tar tmp_extract actual_sha
  for candidate_key in "${candidate_keys[@]}"; do
    candidate_cache_xcframework="$CACHE_ROOT/$candidate_key/GhosttyKit.xcframework"
    if [[ "$candidate_key" != "$GHOSTTY_CLEAN_KEY" ]]; then
      echo "==> Trying legacy GhosttyKit prebuilt key: $candidate_key"
    fi
    if [[ -d "$candidate_cache_xcframework" ]]; then
      mkdir -p "$(dirname "$LOCAL_XCFRAMEWORK")"
      rm -rf "$LOCAL_XCFRAMEWORK"
      cp -R "$candidate_cache_xcframework" "$LOCAL_XCFRAMEWORK"
      set_ghostty_cache_key "$candidate_key"
      echo "$GHOSTTY_KEY" > "$LOCAL_KEY_STAMP"
      echo "$GHOSTTY_SHA" > "$LEGACY_LOCAL_SHA_STAMP"
      return 0
    fi

    url="https://github.com/manaflow-ai/ghostty/releases/download/xcframework-${candidate_key}/GhosttyKit.xcframework.tar.gz"
    tmp_dir="$(mktemp -d "$CACHE_ROOT/.ghosttykit-prebuilt.XXXXXX")"
    tmp_tar="$tmp_dir/GhosttyKit.xcframework.tar.gz"
    tmp_extract="$tmp_dir/extract"
    mkdir -p "$tmp_extract"
    echo "==> Fetching prebuilt GhosttyKit.xcframework for ${GHOSTTY_SHA:0:12}..."
    if ! curl -fSL --connect-timeout 10 --max-time 300 --retry 3 --retry-delay 2 --retry-all-errors -o "$tmp_tar" "$url"; then
      rm -rf "$tmp_dir"
      continue
    fi

    actual_sha="$(hash_file "$tmp_tar")"
    if [[ "$actual_sha" != "$expected_sha" ]]; then
      rm -rf "$tmp_dir"
      echo "==> Prebuilt xcframework checksum mismatch; falling back to next candidate." >&2
      echo "    expected: $expected_sha" >&2
      echo "    actual:   $actual_sha" >&2
      continue
    fi

    if ! python3 "$GHOSTTYKIT_ARCHIVE_VALIDATOR" "$tmp_tar"; then
      rm -rf "$tmp_dir"
      echo "==> Prebuilt xcframework archive failed validation; falling back to next candidate." >&2
      continue
    fi

    if ! tar --no-same-owner -xzf "$tmp_tar" -C "$tmp_extract"; then
      rm -rf "$tmp_dir"
      echo "==> Failed to extract verified prebuilt xcframework; falling back to next candidate." >&2
      continue
    fi

    local extracted="$tmp_extract/GhosttyKit.xcframework"
    if [[ ! -d "$extracted" ]]; then
      rm -rf "$tmp_dir"
      echo "==> Prebuilt archive did not contain GhosttyKit.xcframework; falling back to next candidate." >&2
      continue
    fi

    mkdir -p "$(dirname "$LOCAL_XCFRAMEWORK")"
    rm -rf "$LOCAL_XCFRAMEWORK"
    mv "$extracted" "$LOCAL_XCFRAMEWORK"
    rm -rf "$tmp_dir"
    set_ghostty_cache_key "$candidate_key"
    echo "$GHOSTTY_KEY" > "$LOCAL_KEY_STAMP"
    echo "$GHOSTTY_SHA" > "$LEGACY_LOCAL_SHA_STAMP"
    return 0
  done

  echo "==> Prebuilt xcframework not available; falling back to local build."
  return 1
}

if [[ -d "$CACHE_XCFRAMEWORK" ]]; then
  echo "==> Reusing cached GhosttyKit.xcframework"
else
  LOCAL_KEY=""
  if [[ -f "$LOCAL_KEY_STAMP" ]]; then
    LOCAL_KEY="$(cat "$LOCAL_KEY_STAMP")"
  elif [[ -f "$LEGACY_LOCAL_SHA_STAMP" ]]; then
    LOCAL_KEY="$(cat "$LEGACY_LOCAL_SHA_STAMP")"
  fi

  if [[ -d "$LOCAL_XCFRAMEWORK" && "$LOCAL_KEY" == "$GHOSTTY_KEY" ]]; then
    echo "==> Seeding cache from existing local GhosttyKit.xcframework (build key matches)"
  elif try_fetch_prebuilt_xcframework; then
    echo "==> Seeding cache from prebuilt GhosttyKit.xcframework"
  else
    echo "==> Building GhosttyKit.xcframework (this may take a few minutes)..."
    (
      cd ghostty
      env -u SDKROOT "$ZIG_BIN" build -Dcrash-report-subdir="$GHOSTTYKIT_CRASH_REPORT_SUBDIR" -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast
    )
    echo "$GHOSTTY_KEY" > "$LOCAL_KEY_STAMP"
    echo "$GHOSTTY_SHA" > "$LEGACY_LOCAL_SHA_STAMP"
  fi

  if [[ ! -d "$LOCAL_XCFRAMEWORK" ]]; then
    echo "Error: GhosttyKit.xcframework not found at $LOCAL_XCFRAMEWORK" >&2
    exit 1
  fi

  TMP_DIR="$(mktemp -d "$CACHE_ROOT/.ghosttykit-tmp.XXXXXX")"
  mkdir -p "$CACHE_DIR"
  cp -R "$LOCAL_XCFRAMEWORK" "$TMP_DIR/GhosttyKit.xcframework"
  rm -rf "$CACHE_XCFRAMEWORK"
  mv "$TMP_DIR/GhosttyKit.xcframework" "$CACHE_XCFRAMEWORK"
  rmdir "$TMP_DIR"
  echo "==> Cached GhosttyKit.xcframework at $CACHE_XCFRAMEWORK"
fi

MACOS_ARCHIVE="$CACHE_XCFRAMEWORK/macos-arm64_x86_64/libghostty.a"
if [[ -f "$MACOS_ARCHIVE" ]]; then
  # Xcode 26 can fail to resolve symbols from Ghostty's universal static archive
  # until its ranlib index is refreshed after reuse or copy.
  echo "==> Refreshing libghostty archive index..."
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "error: xcrun is required to refresh libghostty archive index." >&2
    exit 1
  fi
  if ! XCODE_RANLIB="$(xcrun --find ranlib 2>/dev/null)"; then
    echo "error: could not locate ranlib via xcrun." >&2
    exit 1
  fi
  "$XCODE_RANLIB" "$MACOS_ARCHIVE"
fi

echo "==> Creating symlink for GhosttyKit.xcframework..."
ln -sfn "$CACHE_XCFRAMEWORK" GhosttyKit.xcframework
