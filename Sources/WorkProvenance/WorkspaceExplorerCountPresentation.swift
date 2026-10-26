import Foundation

/// Formats only counts whose source facts are known for the current Explorer phase.
enum WorkspaceExplorerCountPresentation {
    static func overviewLines(_ result: WorkspaceExplorerProjectionResult,
                              scope: WorkspaceExplorerScope,
                              archiveAvailability: WorkspaceExplorerArchiveAvailability,
                              liveMetadataPending: Bool,
                              hasFilters: Bool) -> [String] {
        if liveMetadataPending {
            if scope.period != .anyTime {
                return [loadingActivity + " · " + scope.summary]
            }
            if scope.state == .closed {
                return [closedUnknown(archiveAvailability) + " · " + scope.summary]
            }
            var line = openCount(result.counts.open)
            if scope.state == .all { line += " · " + closedUnknown(archiveAvailability) }
            return [loadingProjects, line + " · " + scope.summary]
        }
        if scope.state == .closed && !result.counts.closedKnown {
            return [closedUnknown(archiveAvailability) + " · " + scope.summary]
        }
        if scope.state == .all && !result.counts.closedKnown {
            return [openCount(result.counts.open) + " · " + closedUnknown(archiveAvailability) +
                " · " + scope.summary]
        }
        var lines = [String(format: String(localized: "explorer.overviewScopedCount", defaultValue:
            "%d projects · %d workspaces · %@"), result.inScopeProjectIDs.count,
            result.counts.workspaces, scope.summary)]
        if hasFilters {
            lines.append(String(format: String(localized: "explorer.projectsShown", defaultValue:
                "%d of %d projects shown"), result.visibleProjectIDs.count,
                result.inScopeProjectIDs.count))
        }
        return lines
    }

    static func collection(_ result: WorkspaceExplorerProjectionResult,
                           scope: WorkspaceExplorerScope,
                           archiveAvailability: WorkspaceExplorerArchiveAvailability,
                           liveMetadataPending: Bool,
                           hasFilters: Bool) -> String {
        if liveMetadataPending && scope.period != .anyTime {
            return loadingActivity + " · " + scope.summary
        }
        if scope.state == .closed && !result.counts.closedKnown {
            return closedUnknown(archiveAvailability) + " · " + scope.summary
        }
        if scope.state == .all && !result.counts.closedKnown {
            return openCount(result.counts.open) + " · " + closedUnknown(archiveAvailability) +
                " · " + scope.summary
        }
        let label: String
        switch scope.state {
        case .open: label = String(localized: "explorer.count.open", defaultValue: "open workspaces")
        case .all: label = String(localized: "explorer.count.all", defaultValue: "workspaces")
        case .closed: label = String(localized: "explorer.count.past", defaultValue: "past workspaces")
        }
        var total = "\(result.counts.workspaces) \(label)"
        if scope.state == .all {
            total += " · " + String(format: String(localized: "explorer.count.breakdown", defaultValue:
                "%d open · %d past"), result.counts.open, result.counts.closed)
        }
        total += " · " + scope.summary
        guard hasFilters else { return total }
        return String(format: String(localized: "explorer.visibleOfTotal", defaultValue: "%d of %@"),
            result.visibleCounts.workspaces, total)
    }

    static var loadingProjects: String {
        String(localized: "explorer.projectsLoading", defaultValue: "Loading project information…")
    }

    static var loadingActivity: String {
        String(localized: "explorer.activityLoading", defaultValue: "Loading workspace activity…")
    }

    private static func openCount(_ count: Int) -> String {
        String(format: String(localized: "explorer.count.openTotal", defaultValue: "%d open workspaces"), count)
    }

    private static func closedUnknown(_ availability: WorkspaceExplorerArchiveAvailability) -> String {
        availability.closedCountLabel ?? String(localized: "explorer.count.pastUnknown", defaultValue:
            "past history incomplete")
    }
}
