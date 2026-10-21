import Foundation

/// The Explorer's display facts and its pure grouping inputs from one history load.
struct WorkspaceExplorerCatalog {
    let items: [WorkspaceExplorerHistoryItem]
    let projects: [WorkspaceExplorerProject]
    let workspaces: [WorkspaceExplorerWorkspace]
    let archiveAvailability: WorkspaceExplorerArchiveAvailability
    let partialLiveActivity: Bool

    var archiveAvailable: Bool { archiveAvailability == .available }

    init(_ result: WorkspaceExplorerHistoryLoadResult,
         liveStatuses: [String: WorkspaceExplorerStatus] = [:],
         arrangedStatuses: [String: WorkspaceExplorerStatus] = [:]) {
        items = result.items.map { item in
            liveStatuses[item.id].map(item.withLiveStatus) ?? item
        }
        archiveAvailability = result.archiveAvailability
        partialLiveActivity = result.partialLiveActivity

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

    var projection: WorkspaceExplorerProjection {
        WorkspaceExplorerProjection(projects: projects, workspaces: workspaces,
            archiveAvailable: archiveAvailable)
    }
}
