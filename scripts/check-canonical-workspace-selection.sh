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
if command -v rg >/dev/null 2>&1; then
    selection_lines="$(rg -n -P '\b([A-Za-z_][A-Za-z0-9_]*(?:[?!])?\.)*selectedTabId\s*=(?!=)' Sources --glob '*.swift' || true)"
    adapter_selection_lines="$(rg -n -P '\.selectWorkspace\(' Sources --glob '*.swift' || true)"
    control_adapter_selection_alias_lines="$(rg -n -P '\.selectTab\(' Sources/TerminalController+Control*.swift --glob '*.swift' || true)"
else
    selection_lines="$(grep -RInE --include='*.swift' 'selectedTabId[[:space:]]*=' Sources || true)"
    adapter_selection_lines="$(grep -RInE --include='*.swift' '\.selectWorkspace\(' Sources || true)"
    control_adapter_selection_alias_lines="$(grep -InE '\.selectTab\(' Sources/TerminalController+Control*.swift || true)"
fi

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  file="${line%%:*}"
  rest="${line#*:}"
  source_line="${rest#*:}"
  [[ "$source_line" =~ (^|[[:space:]])(let|var)[[:space:]]+selectedTabId[[:space:]]*= ]] && continue
  if [[ "$source_line" =~ selectedTabId[[:space:]]*== ]] &&
     [[ ! "$source_line" =~ selectedTabId[[:space:]]*=[[:space:]]*[^=] ]]; then
    continue
  fi
  is_allowed_file "$file" && continue
  violations+=("$line")
done <<< "$selection_lines"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  file="${line%%:*}"
  rest="${line#*:}"
  source_line="${rest#*:}"
  [[ "$source_line" =~ ^[[:space:]]*case[[:space:]]+\.selectWorkspace\( ]] && continue
  is_allowed_file "$file" && continue
  violations+=("$line")
done <<< "$adapter_selection_lines"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done <<< "$control_adapter_selection_alias_lines"

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-canonical-workspace-selection: direct workspace selection mutations must stay in the workspace selection domain."
    echo "Use TabManager.selectWorkspaceIdForAction/focusWorkspaceSurfaceForAction/focusTab, or extend the domain path when a new mutation policy is needed."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-canonical-workspace-selection: ok"
