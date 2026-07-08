#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-${BMUX_APP_PATH:-}}"
TAG="${BMUX_TAG:-ca-main-thread}"
SOCKET_PATH="${BMUX_CA_ASSERT_SOCKET_PATH:-/tmp/bmux-debug-${TAG}.sock}"
LOG_PATH="${BMUX_CA_ASSERT_LOG:-/tmp/bmux-ca-main-thread-${TAG}.log}"
HOLD_SECONDS="${BMUX_CA_ASSERT_HOLD_SECONDS:-8}"
READY_TIMEOUT_SECONDS="${BMUX_CA_ASSERT_READY_TIMEOUT_SECONDS:-60}"
APP_PID_FILE="${BMUX_CA_ASSERT_PID_FILE:-/tmp/bmux-ca-main-thread-${TAG}.pid}"

if [ -z "$APP_PATH" ]; then
  echo "usage: BMUX_APP_PATH=/path/to/bmux.app $0" >&2
  echo "   or: $0 /path/to/bmux.app" >&2
  echo "optional: BMUX_CA_ASSERT_SOCKET_PATH=/tmp/bmux-debug-<tag>.sock" >&2
  exit 2
fi

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: app bundle not found: $APP_PATH" >&2
  exit 2
fi

APP_BASENAME="$(basename "$APP_PATH")"
if [ "$APP_BASENAME" = "bmux DEV.app" ] && [ "${BMUX_ALLOW_UNTAGGED_CA_REGRESSION:-0}" != "1" ]; then
  echo "ERROR: refusing to launch untagged bmux DEV.app without BMUX_ALLOW_UNTAGGED_CA_REGRESSION=1" >&2
  exit 2
fi

BINARY="$APP_PATH/Contents/MacOS/bmux DEV"
if [ ! -x "$BINARY" ]; then
  BINARY="$APP_PATH/Contents/MacOS/bmux"
fi

if [ ! -x "$BINARY" ]; then
  echo "ERROR: bmux executable not found in $APP_PATH" >&2
  exit 2
fi

APP_PID=""

kill_recorded_app() {
  if [ ! -f "$APP_PID_FILE" ]; then
    return
  fi

  local recorded_pid
  recorded_pid="$(cat "$APP_PID_FILE" 2>/dev/null || true)"
  case "$recorded_pid" in
    ""|*[!0-9]*)
      rm -f "$APP_PID_FILE"
      return
      ;;
  esac

  local args
  args="$(ps -p "$recorded_pid" -o args= 2>/dev/null || true)"
  if [ -n "$args" ] && [[ "$args" == *"$BINARY"* ]]; then
    kill "$recorded_pid" >/dev/null 2>&1 || true
  fi
  rm -f "$APP_PID_FILE"
}

cleanup() {
  if [ -n "$APP_PID" ]; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$SOCKET_PATH" "$APP_PID_FILE"
}
trap cleanup EXIT

kill_recorded_app
rm -f "$SOCKET_PATH" "$LOG_PATH"

CA_ASSERT_MAIN_THREAD_TRANSACTIONS=1 \
CA_DEBUG_TRANSACTIONS=1 \
BMUX_UI_TEST_MODE=1 \
BMUX_DISABLE_SESSION_RESTORE=1 \
BMUX_SOCKET_ENABLE=1 \
BMUX_SOCKET_MODE=automation \
BMUX_TAG="$TAG" \
BMUX_SOCKET_PATH="$SOCKET_PATH" \
BMUX_ALLOW_SOCKET_OVERRIDE=1 \
"$BINARY" >"$LOG_PATH" 2>&1 &
APP_PID=$!
echo "$APP_PID" >"$APP_PID_FILE"

wait_for_app_alive() {
  if ! kill -0 "$APP_PID" >/dev/null 2>&1; then
    wait "$APP_PID" >/dev/null 2>&1 || true
    echo "FAIL: bmux exited while CA_ASSERT_MAIN_THREAD_TRANSACTIONS=1 was active" >&2
    echo "--- app log tail ($LOG_PATH) ---" >&2
    tail -80 "$LOG_PATH" >&2 2>/dev/null || true
    exit 1
  fi
}

ready_deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
socket_ready=0
while [ "$SECONDS" -lt "$ready_deadline" ]; do
  wait_for_app_alive
  if [ -S "$SOCKET_PATH" ]; then
    socket_ready=1
    break
  fi
  sleep 0.25
done

if [ "$socket_ready" -ne 1 ]; then
  echo "FAIL: bmux stayed alive but did not create its socket at $SOCKET_PATH" >&2
  echo "--- app log tail ($LOG_PATH) ---" >&2
  tail -80 "$LOG_PATH" >&2 2>/dev/null || true
  exit 1
fi

hold_deadline=$((SECONDS + HOLD_SECONDS))
while [ "$SECONDS" -lt "$hold_deadline" ]; do
  wait_for_app_alive
  sleep 0.25
done

if grep -E "uncommitted CATransaction|implicit transaction wasn't created|CoreAnimation.*thread|CATransaction.*thread" "$LOG_PATH" >/dev/null 2>&1; then
  echo "FAIL: CoreAnimation reported a worker-thread transaction" >&2
  echo "--- app log tail ($LOG_PATH) ---" >&2
  tail -80 "$LOG_PATH" >&2 2>/dev/null || true
  exit 1
fi

echo "PASS: bmux startup survived CoreAnimation main-thread transaction assertions"
