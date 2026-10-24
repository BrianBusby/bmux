import Foundation

/// The Explorer's display facts and its pure grouping inputs from one history load.
struct WorkspaceExplorerCatalog {
    let items: [WorkspaceExplorerHistoryItem]
    let projects: [WorkspaceExplorerProject]
    let workspaces: [WorkspaceExplorerWorkspace]
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let partialLiveActivity: Bool
    let liveMetadataPending: Bool

    var archiveAvailable: Bool { archiveAvailability == .available }

    init(_ result: WorkspaceExplorerHistoryLoadResult,
         liveStatuses: [String: WorkspaceExplorerStatus] = [:],
         arrangedStatuses: [String: WorkspaceExplorerStatus] = [:]) {
        items = result.items.map { item in
            liveStatuses[item.id].map(item.withLiveStatus) ?? item
        }
        archiveAvailability = result.archiveAvailability
        partialLiveActivity = result.partialLiveActivity
        liveMetadataPending = result.liveMetadataPending

        var namesByID: [String: String] = [:]
        for item in result.items {
            for link in item.display?.projectLinks ?? [] {
                namesByID[link.id] = link.title ?? namesByID[link.id] ?? link.id
            }
        }
        projects = namesByID.map { id, name in
            WorkspaceExplorerProject(id: id, name: name, owner: nil, status: nil)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        workspaces = items.map { item in
            let display = item.display
            let status = item.liveStatus
            return WorkspaceExplorerWorkspace(
                id: item.id,
                title: item.title,
                projectIDs: display?.projectLinks.map(\.id) ?? [],
                repository: display?.repositoryID,
                tickets: display?.ticketIDs ?? [],
                ticketStatus: nil,
                pullRequestOwner: display?.pullRequestOwnerLogin,
                pullRequestStatus: display?.pullRequestStatus,
                hasPullRequest: display?.pullRequestNumber != nil,
                lastActivityAt: item.lastActivityAt,
                isClosed: !item.isOpen,
                liveStatus: status,
                arrangedStatus: arrangedStatuses[item.id] ?? status
            )
        }
    }

    private init(items: [WorkspaceExplorerHistoryItem], projects: [WorkspaceExplorerProject],
                 workspaces: [WorkspaceExplorerWorkspace],
                 archiveAvailability: WorkspaceExplorerArchiveAvailability,
                 partialLiveActivity: Bool, liveMetadataPending: Bool) {
        self.items = items
        self.projects = projects
        self.workspaces = workspaces
        self.archiveAvailability = archiveAvailability
        self.partialLiveActivity = partialLiveActivity
        self.liveMetadataPending = liveMetadataPending
    }

    func withCurrentLiveStatuses(from current: Self?) -> Self {
        guard let current else { return self }
        let statusByID = Dictionary(current.items.map { ($0.id, $0.liveStatus) },
            uniquingKeysWith: { first, _ in first })
        return Self(items: items.map { item in
            statusByID[item.id].map(item.withLiveStatus) ?? item
        }, projects: projects, workspaces: workspaces.map { workspace in
            statusByID[workspace.id].map(workspace.withLiveStatus) ?? workspace
        }, archiveAvailability: archiveAvailability,
            partialLiveActivity: partialLiveActivity, liveMetadataPending: liveMetadataPending)
    }

    func project(target: WorkspaceExplorerCollectionTarget?, scope: WorkspaceExplorerScope,
                 arrangement: WorkspaceExplorerViewArrangement,
                 now: Date, calendar: Calendar) -> WorkspaceExplorerProjectionResult? {
        let projection = self.projection
        if let target {
            if liveMetadataPending {
                guard target == .all else { return nil }
                return projection.collection(target: .all, scope: scope,
                    groupBy: [], filters: [:], now: now, calendar: calendar)
            }
            return projection.collection(target: target, scope: scope,
                groupBy: arrangement.groupBy, filters: arrangement.filters,
                now: now, calendar: calendar)
        }
        return projection.overview(scope: scope, groupBy: arrangement.groupBy,
            filters: arrangement.filters, now: now, calendar: calendar)
    }

    var projection: WorkspaceExplorerProjection {
        WorkspaceExplorerProjection(projects: projects, workspaces: workspaces,
            archiveAvailable: archiveAvailable)
    }
}
