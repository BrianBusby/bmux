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
  done < <(rg -n -P "$pattern" Sources Packages --glob '*.swift' --glob '!**/Tests/**' || true)
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

check_pattern \
  'SidebarGitPullRequestObservationRuntimeService\(' \
  'Sources/App/BmuxAppRuntimeComposition.swift constructs sidebar Git/PR observation runtime' \
  'Sources/App/BmuxAppRuntimeComposition.swift'

check_pattern \
  'sidebarGitPullRequestObservationRuntimeService\.(start|stop|detach|tabManagerObservationServices)\(' \
  'Sources/App/BmuxAppRuntimeServices.swift owns sidebar Git/PR observation runtime start, compatibility, and stop' \
  'Sources/App/BmuxAppRuntimeServices.swift'

check_pattern \
  'NotificationPushRuntimeService\(' \
  'Sources/App/BmuxAppRuntimeComposition.swift constructs notification and push runtime' \
  'Sources/App/BmuxAppRuntimeComposition.swift'

check_pattern \
  'notificationPushRuntimeService\.(start|stop|handleApplicationDidBecomeActive|handleNotificationResponse|presentationOptions)\(' \
  'Sources/App/BmuxAppRuntimeServices.swift owns notification and push runtime start, callbacks, and stop' \
  'Sources/App/BmuxAppRuntimeServices.swift'

check_pattern \
  '(?<![[:alnum:]_])MenuBarPresentationRuntimeService\(' \
  'Sources/App/BmuxAppRuntimeComposition.swift constructs menu-bar and presentation runtime' \
  'Sources/App/BmuxAppRuntimeComposition.swift'

check_pattern \
  'menuBarPresentationRuntimeService\.(start|stop|setMenuBarOnly|toggleGlobalSearchPalette|refreshMenuBarExtraForDebugControls)\(' \
  'Sources/App/BmuxAppRuntimeServices.swift owns menu-bar and presentation runtime start, mutation, callbacks, and stop' \
  'Sources/App/BmuxAppRuntimeServices.swift'

check_pattern \
  '(?<![[:alnum:]_])MenuBarExtraController\(' \
  'Sources/AppDelegate+MenuBarPresentationRuntime.swift creates status-item UI adapters for the menu-bar runtime' \
  'Sources/AppDelegate+MenuBarPresentationRuntime.swift'

check_pattern \
  'NSApp\.setActivationPolicy\(' \
  'Sources/App/MenuBarPresentationRuntimeServiceDependencies.swift owns activation-policy mutation' \
  'Sources/App/MenuBarPresentationRuntimeServiceDependencies.swift'

check_pattern \
  'MenuBarOnlySettings\.setEnabled\(' \
  'Sources/App/MenuBarPresentationRuntimeServiceDependencies.swift owns menu-bar-only preference writes for runtime reconciliation' \
  'Sources/App/MenuBarPresentationRuntimeServiceDependencies.swift'

check_pattern \
  'SleepyModeController\.shared\.onStateChange' \
  'Sources/App/MenuBarPresentationRuntimeServiceDependencies.swift owns menu-bar refresh callback installation' \
  'Sources/App/MenuBarPresentationRuntimeServiceDependencies.swift'

check_pattern \
  'MenuBarOnlySettings\.applyActivationPolicy' \
  'activation-policy application must route through MenuBarPresentationRuntimeService dependencies'

check_pattern \
  '(menuBarVisibilityObserver|syncApplicationPresentationPreferences|syncMenuBarExtraVisibility|installMenuBarVisibilityObserver|setupMenuBarExtra|lastMenuBarExtraShouldInstall)' \
  'menu-bar visibility and presentation lifecycle state moved to MenuBarPresentationRuntimeService'

check_pattern \
  'PhonePushClient\.shared\.(configure|stop|forward|forwardDismissed|willForwardReplacement)\(' \
  'Sources/App/NotificationPushRuntimeServiceDependencies.swift owns PhonePushClient lifecycle and forwarding' \
  'Sources/App/NotificationPushRuntimeServiceDependencies.swift'

check_pattern \
  'NotificationDeliveryCoordinator\(' \
  'Sources/App/NotificationPushRuntimeServiceDependencies.swift constructs macOS notification delivery' \
  'Sources/App/NotificationPushRuntimeServiceDependencies.swift'

check_pattern \
  'UIApplication\.shared\.(registerForRemoteNotifications|unregisterForRemoteNotifications)\(' \
  'Packages/iOS/BmuxMobileShellUI/Sources/BmuxMobileShellUI/SystemMobilePushSystemClient.swift owns iOS APNs registration calls' \
  'Packages/iOS/BmuxMobileShellUI/Sources/BmuxMobileShellUI/SystemMobilePushSystemClient.swift'

check_pattern \
  'SidebarGitMetadataService\(' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift constructs sidebar Git observers' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift'

check_pattern \
  'PullRequestPollService\(' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift constructs sidebar PR observers' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift'

check_pattern \
  'PullRequestProbeService\(' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift constructs sidebar PR lookup probes' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift'

check_pattern \
  'WorkspaceGitMetadataProbeLimiter\(' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift owns process-wide sidebar Git probe limiting' \
  'Sources/App/SidebarGitPullRequestObservationRuntimeServiceDependencies.swift'

check_pattern \
  'WorkProvenanceGitHubCLIPullRequestOwnerResolver' \
  'PE/workspace-display consumes canonical PR facts and must not reintroduce a GitHub CLI PR metadata owner' \
  ''

check_pattern \
  'pullRequestOwnerResolver:[[:space:]]*any[[:space:]]+WorkProvenancePullRequestOwnerResolving[[:space:]]*=[[:space:]]*(?!WorkProvenanceNoopPullRequestOwnerResolver\(\))' \
  'WorkProvenanceObservationService defaults to a no-op owner resolver; explicit fakes belong in tests' \
  'Sources/WorkProvenance/WorkProvenanceObservationService.swift'

if (( ${#violations[@]} > 0 )); then
  {
    echo "check-app-runtime-composition-boundary: migrated runtime services must start through the app runtime composition boundary."
    printf '  %s\n' "${violations[@]}"
  } >&2
  exit 1
fi

echo "check-app-runtime-composition-boundary: ok"
