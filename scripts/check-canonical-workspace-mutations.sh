#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

migrated_files=(
  "Sources/BmuxConfigExecutor+WorkspaceLaunch.swift"
  "Sources/Mobile/AgentChat/AgentChatTranscriptService.swift"
  "Sources/AppDelegate.swift"
  "Sources/RemoteTmuxController.swift"
  "Sources/ContentView.swift"
  "Sources/TerminalController.swift"
  "Sources/Workspace.swift"
  "Sources/bmuxApp.swift"
)

workspace_creation_migrated_files=(
  "Sources/TerminalController.swift"
  "Sources/TerminalController+WorkspaceCreate.swift"
)

mutation_pattern='\.((closeWorkspace|reorderWorkspace|clearCustomDescription|setCustomDescription|setTabColor|moveTabToTop|moveTabsToTop)\(|selectTab\(at:)'
creation_mutation_pattern='\.addWorkspace\('

violations=()
if command -v rg >/dev/null 2>&1; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    source_line="${line#*:}"
    source_line="${source_line#*:}"
    [[ "$source_line" =~ ^[[:space:]]*case[[:space:]]+\. ]] && continue
    violations+=("$line")
  done < <(rg -n -P "$mutation_pattern" "${migrated_files[@]}" || true)
else
  while IFS= read -r file; do
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      source_line="${line#*:}"
      [[ "$source_line" =~ ^[[:space:]]*case[[:space:]]+\. ]] && continue
      violations+=("$line")
    done < <(grep -nE '\.(closeWorkspace|reorderWorkspace|clearCustomDescription|setCustomDescription|setTabColor|moveTabToTop|moveTabsToTop)\(' "$file" || true)
  done < <(printf '%s\n' "${migrated_files[@]}")
fi

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  violations+=("$line")
done < <(rg -n -P "$creation_mutation_pattern" "${workspace_creation_migrated_files[@]}" || true)

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-canonical-workspace-mutations: migrated workspace entrypoints must route through domain action helpers."
    echo "Use TabManager workspace ForAction helpers, or extend the domain path when a new mutation policy is needed."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-canonical-workspace-mutations: ok"
