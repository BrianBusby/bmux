#!/usr/bin/env bash

# Source this file from direnv or dev scripts. It intentionally keeps local dev
# database URLs derived from BMUX_PORT so parallel worktrees cannot hit the same
# Postgres instance by accident.

bmux_web_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bmux_existing_bmux_port_set="${BMUX_PORT+x}"
bmux_existing_bmux_port="${BMUX_PORT-}"
bmux_existing_port_set="${PORT+x}"
bmux_existing_port="${PORT-}"
bmux_existing_db_port_offset_set="${BMUX_DB_PORT_OFFSET+x}"
bmux_existing_db_port_offset="${BMUX_DB_PORT_OFFSET-}"
bmux_existing_db_port_set="${BMUX_DB_PORT+x}"
bmux_existing_db_port="${BMUX_DB_PORT-}"
bmux_existing_db_user_set="${BMUX_DB_USER+x}"
bmux_existing_db_user="${BMUX_DB_USER-}"
bmux_existing_db_password_set="${BMUX_DB_PASSWORD+x}"
bmux_existing_db_password="${BMUX_DB_PASSWORD-}"
bmux_existing_db_name_set="${BMUX_DB_NAME+x}"
bmux_existing_db_name="${BMUX_DB_NAME-}"
bmux_existing_freestyle_snapshot_set="${FREESTYLE_SANDBOX_SNAPSHOT+x}"
bmux_existing_freestyle_snapshot="${FREESTYLE_SANDBOX_SNAPSHOT-}"
bmux_existing_e2b_template_set="${E2B_BMUXD_WS_TEMPLATE+x}"
bmux_existing_e2b_template="${E2B_BMUXD_WS_TEMPLATE-}"
bmux_existing_daytona_snapshot_set="${DAYTONA_SANDBOX_SNAPSHOT+x}"
bmux_existing_daytona_snapshot="${DAYTONA_SANDBOX_SNAPSHOT-}"

bmux_extra_secret_file="${BMUXTERM_EXTRA_ENV_FILE:-${BMUX_WEB_EXTRA_ENV_FILE:-}}"
if [[ -z "$bmux_extra_secret_file" && -f "$HOME/.secrets/bmux.env" ]]; then
  bmux_extra_secret_file="$HOME/.secrets/bmux.env"
fi

bmux_secret_file="${BMUXTERM_ENV_FILE:-${BMUX_WEB_ENV_FILE:-}}"
if [[ -z "$bmux_secret_file" ]]; then
  if [[ -f "$HOME/.secrets/bmuxterm-dev.env" ]]; then
    bmux_secret_file="$HOME/.secrets/bmuxterm-dev.env"
  elif [[ -f "$HOME/.secret/bmuxterm.env" ]]; then
    bmux_secret_file="$HOME/.secret/bmuxterm.env"
  elif [[ -f "$HOME/.secrets/bmuxterm.env" ]]; then
    bmux_secret_file="$HOME/.secrets/bmuxterm.env"
  else
    echo "Missing bmux web secrets. Expected ~/.secrets/bmuxterm-dev.env." >&2
    return 1 2>/dev/null || exit 1
  fi
fi

bmux_nounset_was_enabled=0
case "$-" in
  *u*) bmux_nounset_was_enabled=1 ;;
esac
set +u
set -a
if [[ -n "$bmux_extra_secret_file" ]]; then
  # shellcheck disable=SC1090
  source "$bmux_extra_secret_file"
fi
# shellcheck disable=SC1090
source "$bmux_secret_file"
set +a
if ! grep -q '^STACK_SUPER_SECRET_ADMIN_KEY=' "$bmux_secret_file"; then
  unset STACK_SUPER_SECRET_ADMIN_KEY
fi
if [[ "$bmux_nounset_was_enabled" == "1" ]]; then
  set -u
fi

if [[ -n "$bmux_existing_bmux_port_set" ]]; then export BMUX_PORT="$bmux_existing_bmux_port"; fi
if [[ -n "$bmux_existing_port_set" ]]; then export PORT="$bmux_existing_port"; fi
if [[ -n "$bmux_existing_db_port_offset_set" ]]; then export BMUX_DB_PORT_OFFSET="$bmux_existing_db_port_offset"; fi
if [[ -n "$bmux_existing_db_port_set" ]]; then export BMUX_DB_PORT="$bmux_existing_db_port"; fi
if [[ -n "$bmux_existing_db_user_set" ]]; then export BMUX_DB_USER="$bmux_existing_db_user"; fi
if [[ -n "$bmux_existing_db_password_set" ]]; then export BMUX_DB_PASSWORD="$bmux_existing_db_password"; fi
if [[ -n "$bmux_existing_db_name_set" ]]; then export BMUX_DB_NAME="$bmux_existing_db_name"; fi
if [[ -n "$bmux_existing_freestyle_snapshot_set" ]]; then export FREESTYLE_SANDBOX_SNAPSHOT="$bmux_existing_freestyle_snapshot"; fi
if [[ -n "$bmux_existing_e2b_template_set" ]]; then export E2B_BMUXD_WS_TEMPLATE="$bmux_existing_e2b_template"; fi
if [[ -n "$bmux_existing_daytona_snapshot_set" ]]; then export DAYTONA_SANDBOX_SNAPSHOT="$bmux_existing_daytona_snapshot"; fi

bmux_port="${BMUX_PORT:-${PORT:-3777}}"
if [[ ! "$bmux_port" =~ ^[0-9]+$ ]]; then
  echo "BMUX_PORT must be numeric, got: $bmux_port" >&2
  return 2 2>/dev/null || exit 2
fi
export BMUX_PORT="$bmux_port"

bmux_db_offset="${BMUX_DB_PORT_OFFSET:-10000}"
if [[ ! "$bmux_db_offset" =~ ^[0-9]+$ ]]; then
  echo "BMUX_DB_PORT_OFFSET must be numeric, got: $bmux_db_offset" >&2
  return 2 2>/dev/null || exit 2
fi
export BMUX_DB_PORT_OFFSET="$bmux_db_offset"

export BMUX_DB_USER="${BMUX_DB_USER:-bmux}"
export BMUX_DB_PASSWORD="${BMUX_DB_PASSWORD:-bmux}"
export BMUX_DB_NAME="${BMUX_DB_NAME:-bmux}"
export BMUX_DB_PORT="${BMUX_DB_PORT:-$((bmux_port + bmux_db_offset))}"

if [[ "${BMUX_DEV_USE_EXTERNAL_DATABASE_URL:-0}" != "1" ]]; then
  export DATABASE_URL="postgres://${BMUX_DB_USER}:${BMUX_DB_PASSWORD}@localhost:${BMUX_DB_PORT}/${BMUX_DB_NAME}"
  export DIRECT_DATABASE_URL="$DATABASE_URL"
elif [[ -z "${DIRECT_DATABASE_URL:-}" && -n "${DATABASE_URL:-}" ]]; then
  export DIRECT_DATABASE_URL="$DATABASE_URL"
fi

if [[ "${BMUX_DEV_USE_EXTERNAL_VM_API_BASE_URL:-0}" != "1" ]]; then
  export BMUX_VM_API_BASE_URL="http://localhost:${BMUX_PORT}"
fi

# Local dev should not require a checked-in or per-worktree .env.local just to pass
# startup validation for routes the developer is not exercising.
export RESEND_API_KEY="${RESEND_API_KEY:-bmux-local-dev}"
export BMUX_FEEDBACK_FROM_EMAIL="${BMUX_FEEDBACK_FROM_EMAIL:-dev@example.invalid}"
export BMUX_FEEDBACK_RATE_LIMIT_ID="${BMUX_FEEDBACK_RATE_LIMIT_ID:-bmux-feedback-local}"
export BMUX_CLIENT_CONFIG_RATE_LIMIT_ID="${BMUX_CLIENT_CONFIG_RATE_LIMIT_ID:-bmux-client-config-local}"
export BMUX_PUSH_RATE_LIMIT_ID="${BMUX_PUSH_RATE_LIMIT_ID:-bmux-push-local}"

export BMUX_WEB_SECRET_ENV_FILE="$bmux_secret_file"
export BMUX_WEB_EXTRA_SECRET_ENV_FILE="$bmux_extra_secret_file"
export PATH="$bmux_web_dir/node_modules/.bin:$PATH"
