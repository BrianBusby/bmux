import Foundation
import ProvenanceEngineContracts

/// The Explorer's display facts and its pure grouping inputs from one history load.
struct WorkspaceExplorerCatalog {
    let items: [WorkspaceExplorerHistoryItem]
    let projects: [WorkspaceExplorerProject]
    let workspaces: [WorkspaceExplorerWorkspace]
    let repositoryNamesByID: [String: String]
    let filterFacets: [ProvenanceWorkspaceHistoryFacet]
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
        repositoryNamesByID = result.repositoryNamesByID
        filterFacets = result.filterFacets.filter { UUID(uuidString: $0.workspaceID) != nil }

        var namesByID: [String: String] = [:]
        for facet in filterFacets {
            for link in facet.projectLinks {
                namesByID[link.id] = link.title ?? namesByID[link.id] ?? link.id
            }
        }
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
                repository: display?.repositoryID ?? item.repositoryID,
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
                 partialLiveActivity: Bool, liveMetadataPending: Bool,
                 repositoryNamesByID: [String: String],
                 filterFacets: [ProvenanceWorkspaceHistoryFacet]) {
        self.items = items
        self.projects = projects
        self.workspaces = workspaces
        self.archiveAvailability = archiveAvailability
        self.partialLiveActivity = partialLiveActivity
        self.liveMetadataPending = liveMetadataPending
        self.repositoryNamesByID = repositoryNamesByID
        self.filterFacets = filterFacets
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
            partialLiveActivity: partialLiveActivity, liveMetadataPending: liveMetadataPending,
            repositoryNamesByID: repositoryNamesByID, filterFacets: filterFacets)
    }

    func filterOptions(dimensions: [WorkspaceExplorerDimension],
                       target: WorkspaceExplorerCollectionTarget, scope: WorkspaceExplorerScope,
                       inScopeWorkspaceIDs: [String], now: Date, calendar: Calendar)
        -> [WorkspaceExplorerDimension: [WorkspaceExplorerGroupKey]] {
        var options = projection.filterOptions(dimensions: dimensions,
            inScopeWorkspaceIDs: inScopeWorkspaceIDs, overview: false)
        guard scope.state != .open else { return options }
        let eligible = filterFacets.filter { facet in
            guard scope.includes(activityAt: facet.lastActivityAt, now: now, calendar: calendar) else {
                return false
            }
            switch target {
            case .all: return true
            case .unassigned: return facet.projectLinks.isEmpty
            case .project(let id): return facet.projectLinks.contains { $0.id == id }
            }
        }
        let projectNames = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
        for dimension in dimensions {
            var keys = Set(options[dimension] ?? [])
            for facet in eligible {
                switch dimension {
                case .repository:
                    keys.insert(facet.repositoryID.map(WorkspaceExplorerGroupKey.value) ??
                        .missing("Unknown repository"))
                case .project:
                    for link in facet.projectLinks { keys.insert(.project(link.id)) }
                case .pullRequestOwner:
                    keys.insert(facet.pullRequestOwnerLogin.map(WorkspaceExplorerGroupKey.value) ??
                        .missing("No PR"))
                case .bmuxStatus:
                    keys.insert(.bmuxStatus(.closedHistorical))
                default: break
                }
            }
            options[dimension] = keys.filter { $0.supportsFocus(in: dimension, overview: false) }
                .sorted { dimension.precedes($0, $1,
                    projectNames: projectNames,
                    repositoryNames: repositoryNamesByID) }
        }
        return options
    }

    func project(target: WorkspaceExplorerCollectionTarget, scope: WorkspaceExplorerScope,
                 arrangement: WorkspaceExplorerViewArrangement,
                 now: Date, calendar: Calendar) -> WorkspaceExplorerProjectionResult? {
        let projection = self.projection
        if liveMetadataPending {
            guard target == .all else { return nil }
            return projection.collection(target: .all, scope: scope,
                groupBy: [], filters: [:], now: now, calendar: calendar)
        }
        return projection.collection(target: target, scope: scope,
            groupBy: arrangement.groupBy, filters: arrangement.filters,
            now: now, calendar: calendar)
    }

    var projection: WorkspaceExplorerProjection {
        WorkspaceExplorerProjection(projects: projects, workspaces: workspaces,
            archiveAvailable: archiveAvailable, repositoryNamesByID: repositoryNamesByID)
    }
}
