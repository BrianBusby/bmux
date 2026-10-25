import SwiftUI

/// Empty-state presentation from immutable Explorer snapshots and actions.
struct WorkspaceExplorerEmptyCollectionView: View {
    let liveMetadataPending: Bool
    let scope: WorkspaceExplorerScope
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let archiveAvailable: Bool
    let hasFilters: Bool
    let anyTimeWorkspaceCount: Int
    let closedWorkspaceCount: Int
    let closedCountLabel: String
    let onClearFilters: () -> Void
    let onAnyTime: () -> Void
    let onShowAll: () -> Void
    let onShowClosed: () -> Void

    var body: some View {
        Group {
            if liveMetadataPending && scope.period != .anyTime {
                ContentUnavailableView(String(localized: "explorer.activityLoading", defaultValue:
                    "Loading workspace activity…"), systemImage: "clock")
            } else if archiveAvailability == .pending &&
                (scope.state != .open || scope.period != .anyTime) {
                ContentUnavailableView(String(localized: "explorer.historyLoadingTitle", defaultValue:
                    "Loading retained history…"), systemImage: "clock")
            } else if archiveAvailability == .unavailable && scope.state == .closed {
                ContentUnavailableView(String(localized: "explorer.historyUnavailableTitle", defaultValue:
                    "Retained history unavailable"), systemImage: "exclamationmark.triangle")
            } else if hasFilters {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noFilterMatches", defaultValue:
                        "No workspaces match these filters"), systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button(String(localized: "explorer.clearFilters", defaultValue: "Clear filters")) {
                        onClearFilters()
                    }
                }
            } else if scope.period != .anyTime {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noActivity", defaultValue: "No activity in this period"),
                        systemImage: "clock")
                } description: {
                    Text(String(format: String(localized: "explorer.anyTimeTotal", defaultValue:
                        "%d workspaces at any time. Capture may also be incomplete."), anyTimeWorkspaceCount))
                } actions: {
                    Button(String(localized: "explorer.anyTime", defaultValue: "Any time")) {
                        onAnyTime()
                    }
                }
            } else if scope.state == .open {
                ContentUnavailableView {
                    Label(String(localized: "explorer.noOpenWorkspaces", defaultValue:
                        "No open workspaces"), systemImage: "square.grid.2x2")
                } description: {
                    if archiveAvailable {
                        Text(String(format: String(localized: "explorer.closedRetained", defaultValue:
                            "%d closed workspaces retained."), closedWorkspaceCount))
                    } else {
                        Text(closedCountLabel)
                    }
                } actions: {
                    Button(String(localized: "explorer.showAll", defaultValue: "Show all")) {
                        onShowAll()
                    }
                    Button(String(localized: "explorer.showClosed", defaultValue: "Show closed")) {
                        onShowClosed()
                    }
                }
            } else {
                ContentUnavailableView(String(localized: "explorer.noWorkspaces", defaultValue:
                    "No workspaces in this scope"), systemImage: "square.grid.2x2")
            }
        }
    }

}
