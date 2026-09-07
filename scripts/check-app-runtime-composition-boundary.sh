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

check_pattern \
  'MobileHostService\.shared\.configure\(auth:' \
  'Sources/App/MobileHostRuntimeService.swift configures the mobile host listener' \
  'Sources/App/MobileHostRuntimeService.swift' \
  'Sources/App/MobileHostRuntimeServiceDependencies.swift'

check_pattern \
  'MobileHostService\.shared\.(start|syncToSettings)\(' \
  'Sources/App/MobileHostRuntimeService.swift starts or syncs the mobile host listener' \
  'Sources/App/MobileHostRuntimeService.swift' \
  'Sources/App/MobileHostRuntimeServiceDependencies.swift'

check_pattern \
  'MobileHostService\.shared\.stop\(' \
  'Sources/App/MobileHostRuntimeService.swift stops the mobile host listener' \
  'Sources/App/MobileHostRuntimeService.swift' \
  'Sources/App/MobileHostRuntimeServiceDependencies.swift'

check_pattern \
  'PresenceHeartbeatClient\.shared\.(configure|start|syncToSettings|stop|appWillTerminate)\(' \
  'Sources/App/MobileHostRuntimeService.swift owns presence heartbeat lifecycle' \
  'Sources/App/MobileHostRuntimeService.swift' \
  'Sources/App/MobileHostRuntimeServiceDependencies.swift'

check_pattern \
  '(DeviceRegistryClient|MacPairedMacBackupPublisher)\.shared\.(configure|start|stop)\(' \
  'Sources/App/MobileHostRuntimeService.swift owns route publication lifecycle' \
  'Sources/App/MobileHostRuntimeService.swift' \
  'Sources/App/MobileHostRuntimeServiceDependencies.swift'

check_pattern \
  'MobileTerminalRenderObserver\.shared\.(start|stop)\(' \
  'Sources/App/MobileHostRuntimeService.swift owns mobile render observation lifecycle' \
  'Sources/App/MobileHostRuntimeService.swift' \
  'Sources/App/MobileHostRuntimeServiceDependencies.swift'

check_pattern \
  'BrowserDevToolsRuntimeService\(' \
  'Sources/App/BmuxAppRuntimeComposition.swift constructs Browser/DevTools runtime' \
  'Sources/App/BmuxAppRuntimeComposition.swift'

check_pattern \
  'BrowserSystemProxyWatcher\.shared\.(startObserving|stopObserving)\(' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift owns system proxy observation lifecycle' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift'

check_pattern \
  'WebViewInspectorTeardown\.closeAllInspectors\(in: NSApp\.windows\)' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift owns app teardown inspector close' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift'

check_pattern \
  'BrowserProfileStore\.shared\.flushPendingSaves\(' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift owns profile save drain at shutdown' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift'

check_pattern \
  'BrowserPrewarmedWebViewPool\.shared\.discard\(' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift owns prewarmed browser resource drain at shutdown' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift'

check_pattern \
  'browserDevToolsRuntimeService\.(start|stop|stopForAppTermination)\(' \
  'Sources/App/BmuxAppRuntimeServices.swift owns Browser/DevTools runtime start and stop' \
  'Sources/App/BmuxAppRuntimeServices.swift'

check_pattern \
  'installBrowserAddressBarFocusObservers' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift owns Browser address/focus observers' \
  'Sources/App/BrowserDevToolsRuntimeServiceDependencies.swift'

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-app-runtime-composition-boundary: migrated runtime services must start through the app runtime composition boundary."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-app-runtime-composition-boundary: ok"
