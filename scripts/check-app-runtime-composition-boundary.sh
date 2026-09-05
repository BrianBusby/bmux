#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

violations=()

is_allowed() {
  local file="$1"
  shift
  local allowed
  for allowed in "$@"; do
    [[ "$file" == "$allowed" ]] && return 0
  done
  return 1
}

check_pattern() {
  local pattern="$1"
  local expected_path="$2"
  shift 2
  local allowed_files=("$@")
  local line file rest source_line

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    file="${line%%:*}"
    rest="${line#*:}"
    source_line="${rest#*:}"
    [[ "$source_line" =~ ^[[:space:]]*// ]] && continue
    is_allowed "$file" "${allowed_files[@]}" && continue
    violations+=("$line  expected: $expected_path")
  done < <(rg -n -P "$pattern" Sources --glob '*.swift' || true)
}

check_pattern \
  'WorkProvenanceRuntime\.live\(' \
  'Sources/App/BmuxAppRuntimeComposition.swift constructs PE runtime' \
  'Sources/App/BmuxAppRuntimeComposition.swift'

check_pattern \
  'workProvenanceRuntime\??\.start\(tabManager:' \
  'Sources/App/BmuxAppRuntimeServices.swift starts PE observation' \
  'Sources/App/BmuxAppRuntimeServices.swift'

check_pattern \
  'workProvenanceRuntime\??\.startExecutionTelemetryProjection\(' \
  'Sources/App/BmuxAppRuntimeServices.swift starts PE telemetry projection' \
  'Sources/App/BmuxAppRuntimeServices.swift'

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-app-runtime-composition-boundary: migrated runtime services must start through the app runtime composition boundary."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-app-runtime-composition-boundary: ok"
