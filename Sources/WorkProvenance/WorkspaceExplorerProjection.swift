import Foundation

/// Pure scope, grouping, filtering, and counting for the separate native Explorer.
struct WorkspaceExplorerProjection {
    let projects: [WorkspaceExplorerProject]
    let workspaces: [WorkspaceExplorerWorkspace]
    let archiveAvailable: Bool
    let repositoryNamesByID: [String: String]

    init(projects: [WorkspaceExplorerProject], workspaces: [WorkspaceExplorerWorkspace],
         archiveAvailable: Bool, repositoryNamesByID: [String: String] = [:]) {
        self.projects = projects
        self.workspaces = workspaces
        self.archiveAvailable = archiveAvailable
        self.repositoryNamesByID = repositoryNamesByID
    }

    func filterOptions(
        dimensions: [WorkspaceExplorerDimension],
        inScopeWorkspaceIDs: [String],
        overview: Bool
    ) -> [WorkspaceExplorerDimension: [WorkspaceExplorerGroupKey]] {
        let byID = Dictionary(workspaces.map { ($0.id, $0) }, uniquingKeysWith: { current, candidate in
            current.isClosed && !candidate.isClosed ? candidate : current
        })
        let members = inScopeWorkspaceIDs.compactMap { byID[$0] }
        let projectIDs = Set(members.flatMap(\.projectIDs))
        let projectNames = Dictionary(projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return Dictionary(uniqueKeysWithValues: dimensions.map { dimension in
            let keys: [WorkspaceExplorerGroupKey]
            switch dimension {
            case .projectOwner, .projectStatus:
                keys = projects.filter { projectIDs.contains($0.id) }.map { project in
                    dimension.projectKey(project, workspaces: members.filter { $0.projectIDs.contains(project.id) })
                }
            case .project:
                keys = members.flatMap { workspace in
                    workspace.projectIDs.isEmpty ? [.unassigned] :
                        workspace.projectIDs.map(WorkspaceExplorerGroupKey.project)
                }
            case .ticket:
                keys = members.flatMap { $0.tickets.map(WorkspaceExplorerGroupKey.value) }
            default:
                keys = members.map { dimension.workspaceKey($0) }
            }
            let options = Set(keys).filter {
                $0.supportsFocus(in: dimension, overview: overview) &&
                    !(overview && dimension == .project && $0 == .unassigned)
            }
                .sorted { dimension.precedes($0, $1, projectNames: projectNames,
                    repositoryNames: repositoryNamesByID) }
            return (dimension, options)
        })
    }

    func overview(
        scope: WorkspaceExplorerScope,
        groupBy: [WorkspaceExplorerDimension],
        filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey],
        now: Date,
        calendar: Calendar
    ) -> WorkspaceExplorerProjectionResult {
        let scoped = scopedWorkspaces(scope, now: now, calendar: calendar)
        let projectRows = projects.compactMap { project -> (WorkspaceExplorerProject, [WorkspaceExplorerWorkspace])? in
            let members = scoped.filter { $0.projectIDs.contains(project.id) }
            return members.isEmpty ? nil : (project, members)
        }
        let workspaceFilters = filters.filter {
            $0.key == .repository || $0.key == .bmuxStatus || $0.key == .pullRequestOwner
        }
        let visible = projectRows.filter { project, members in
            let projectMatches = filters.allSatisfy { dimension, value in
                switch dimension {
                case .project:
                    return value == .project(project.id)
                case .projectOwner, .projectStatus:
                    return dimension.projectKey(project, workspaces: members) == value
                default:
                    return true
                }
            }
            return projectMatches && (workspaceFilters.isEmpty ||
                members.contains { workspaceMatches($0, filters: workspaceFilters) })
        }
        let dimensions = Array(groupBy.filter(\.isOverviewDimension).uniqued().prefix(3))
        let groups = groupProjects(visible, dimensions: dimensions)
        let visibleWorkspaces = visible.flatMap(\.1)
        let matchingWorkspaces = visibleWorkspaces.filter { workspaceMatches($0, filters: workspaceFilters) }
        let matching = Dictionary(uniqueKeysWithValues: visible.map { project, members in
            (project.id, members.filter { workspaceMatches($0, filters: workspaceFilters) }.count)
        })
        return WorkspaceExplorerProjectionResult(
            groups: groups,
            inScopeProjectIDs: projectRows.map { $0.0.id },
            visibleProjectIDs: visible.map { $0.0.id },
            inScopeWorkspaceIDs: scoped.map(\.id),
            visibleWorkspaceIDs: Array(Set(matchingWorkspaces.map(\.id))).sorted(),
            counts: WorkspaceExplorerCounts(scoped, closedKnown: archiveAvailable),
            visibleCounts: WorkspaceExplorerCounts(matchingWorkspaces, closedKnown: archiveAvailable),
            matchingWorkspacesByProjectID: matching
        )
    }

    func collection(
        target: WorkspaceExplorerCollectionTarget,
        scope: WorkspaceExplorerScope,
        groupBy: [WorkspaceExplorerDimension],
        filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey],
        now: Date,
        calendar: Calendar
    ) -> WorkspaceExplorerProjectionResult {
        let names = Dictionary(projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let scoped = scopedWorkspaces(scope, now: now, calendar: calendar).filter { workspace in
            switch target {
            case .all: return true
            case .unassigned: return workspace.projectIDs.isEmpty
            case .project(let id): return workspace.projectIDs.contains(id)
            }
        }
        let visible = scoped.filter { workspaceMatches($0, filters: filters) }
        let dimensions = Array(groupBy.filter { dimension in
            dimension != .workspaceState || scope.state == .all
        }.filter { dimension in
            dimension != .project || target == .all
        }.filter { !$0.isOverviewDimension || $0 == .repository }.uniqued().prefix(3))
        let groups = groupWorkspaces(visible, dimensions: dimensions, names: names)
        return WorkspaceExplorerProjectionResult(
            groups: groups,
            inScopeProjectIDs: [],
            visibleProjectIDs: [],
            inScopeWorkspaceIDs: scoped.map(\.id),
            visibleWorkspaceIDs: visible.map(\.id),
            counts: WorkspaceExplorerCounts(scoped, closedKnown: archiveAvailable),
            visibleCounts: WorkspaceExplorerCounts(visible, closedKnown: archiveAvailable),
            matchingWorkspacesByProjectID: [:]
        )
    }

    private func scopedWorkspaces(_ scope: WorkspaceExplorerScope, now: Date, calendar: Calendar) -> [WorkspaceExplorerWorkspace] {
        var order: [String] = []
        var byID: [String: WorkspaceExplorerWorkspace] = [:]
        for workspace in workspaces {
            if let current = byID[workspace.id] {
                if current.isClosed && !workspace.isClosed { byID[workspace.id] = workspace }
            } else {
                order.append(workspace.id)
                byID[workspace.id] = workspace
            }
        }
        return order.compactMap { byID[$0] }.filter { workspace in
            return scope.includes(workspace, now: now, calendar: calendar)
        }
    }

    private func workspaceMatches(
        _ workspace: WorkspaceExplorerWorkspace,
        filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]
    ) -> Bool {
        filters.allSatisfy { dimension, value in
            if dimension == .project, case .project(let projectID) = value {
                return workspace.projectIDs.contains(projectID)
            }
            if dimension == .ticket, case .value(let ticket) = value {
                return workspace.tickets.contains(ticket)
            }
            return dimension.workspaceKey(workspace) == value
        }
    }

    private func groupWorkspaces(
        _ members: [WorkspaceExplorerWorkspace],
        dimensions: [WorkspaceExplorerDimension],
        names: [String: String]
    ) -> [WorkspaceExplorerGroup] {
        guard let dimension = dimensions.first else {
            return [WorkspaceExplorerGroup(
                dimension: nil, key: nil, value: nil, filterValue: nil, projectIDs: [], workspaceIDs: members.map(\.id),
                counts: WorkspaceExplorerCounts(members, closedKnown: archiveAvailable), children: []
            )]
        }
        let buckets = Dictionary(grouping: members) { dimension.workspaceKey($0) }
        return buckets.keys.sorted { dimension.precedes($0, $1, projectNames: names,
            repositoryNames: repositoryNamesByID) }.map { key in
            let bucket = buckets[key] ?? []
            return WorkspaceExplorerGroup(
                dimension: dimension, key: key, value: key.label(projectNames: names,
                    repositoryNames: dimension == .repository ? repositoryNamesByID : [:]),
                filterValue: key.supportsFocus(in: dimension, overview: false) ? key : nil,
                projectIDs: [], workspaceIDs: bucket.map(\.id),
                counts: WorkspaceExplorerCounts(bucket, closedKnown: archiveAvailable),
                children: groupWorkspaces(bucket, dimensions: Array(dimensions.dropFirst()), names: names)
            )
        }
    }

    private func groupProjects(
        _ rows: [(WorkspaceExplorerProject, [WorkspaceExplorerWorkspace])],
        dimensions: [WorkspaceExplorerDimension]
    ) -> [WorkspaceExplorerGroup] {
        let members = rows.flatMap(\.1)
        guard let dimension = dimensions.first else {
            return [WorkspaceExplorerGroup(
                dimension: nil, key: nil, value: nil, filterValue: nil, projectIDs: rows.map { $0.0.id },
                workspaceIDs: Array(Set(members.map(\.id))).sorted(),
                counts: WorkspaceExplorerCounts(members, closedKnown: archiveAvailable), children: []
            )]
        }
        let buckets = Dictionary(grouping: rows) { project, workspaces in
            dimension.projectKey(project, workspaces: workspaces)
        }
        return buckets.keys.sorted { dimension.precedes($0, $1,
            repositoryNames: repositoryNamesByID) }.map { key in
            let bucket = buckets[key] ?? []
            let bucketMembers = bucket.flatMap(\.1)
            return WorkspaceExplorerGroup(
                dimension: dimension, key: key, value: key.label(
                    repositoryNames: dimension == .repository ? repositoryNamesByID : [:]),
                filterValue: key.supportsFocus(in: dimension, overview: true) ? key : nil,
                projectIDs: bucket.map { $0.0.id },
                workspaceIDs: Array(Set(bucketMembers.map(\.id))).sorted(),
                counts: WorkspaceExplorerCounts(bucketMembers, closedKnown: archiveAvailable),
                children: groupProjects(bucket, dimensions: Array(dimensions.dropFirst()))
            )
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
