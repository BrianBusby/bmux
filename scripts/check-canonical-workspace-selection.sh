#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

allowed_files=(
  "Sources/TabManager.swift"
  "Sources/TabManager+DetachedWorkspace.swift"
  "Sources/Workspace.swift"
)

is_allowed_file() {
  local file="$1"
  local allowed
  for allowed in "${allowed_files[@]}"; do
    [[ "$file" == "$allowed" ]] && return 0
  done
  return 1
}

violations=()
while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  source_line="${rest#*:}"
  [[ "$source_line" =~ (^|[[:space:]])(let|var)[[:space:]]+selectedTabId[[:space:]]*= ]] && continue
  is_allowed_file "$file" && continue
  violations+=("$line")
done < <(rg -n -P '\b([A-Za-z_][A-Za-z0-9_]*\.)?selectedTabId\s*=(?!=)' Sources --glob '*.swift' || true)

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-canonical-workspace-selection: direct selectedTabId assignment must stay in the workspace selection domain."
    echo "Use TabManager.selectWorkspaceIdForAction/selectWorkspace/focusTab, or extend the domain path when a new mutation policy is needed."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-canonical-workspace-selection: ok"
