#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="${ROOT}/Native/CommandPaletteNucleoFFI"
DERIVED_DATA="${BMUX_NUCLEO_FFI_DERIVED_DATA:-/tmp/bmux-nucleo-ffi-unit}"
LOG_PATH="${BMUX_NUCLEO_FFI_LOG:-/tmp/bmux-nucleo-ffi-tests.log}"

cargo build --manifest-path "${CRATE_DIR}/Cargo.toml" --release

LIB_PATH="${CRATE_DIR}/target/release/libbmux_command_palette_nucleo_ffi.dylib"
if [ ! -f "${LIB_PATH}" ]; then
  echo "error: expected nucleo FFI library at ${LIB_PATH}" >&2
  exit 1
fi

if [ "${BMUX_NUCLEO_FFI_CLEAN:-0}" = "1" ]; then
  rm -rf "${DERIVED_DATA}"
fi
NSUnbufferedIO=YES BMUX_NUCLEO_FFI_LIB="${LIB_PATH}" \
  xcodebuild \
    -project "${ROOT}/bmux.xcodeproj" \
    -scheme bmux-unit \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA}" \
    -only-testing:bmuxTests/CommandPaletteNucleoFFITests \
    test | tee "${LOG_PATH}"

if ! grep 'BENCH cmd+p nucleo-ffi' "${LOG_PATH}"; then
  echo "error: CommandPaletteNucleoFFITests did not emit benchmark output" >&2
  exit 1
fi
