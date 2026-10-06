import Foundation

enum WorkspaceStatusKind: String, CaseIterable, Hashable, Sendable {
    case active
    case waiting
    case finished
    case error

    var localizedKey: String { "sidebar.workspaceFilter.status." + rawValue }
}

struct WorkspaceFilterItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let status: WorkspaceStatusKind
    let owner: String?
    let repo: String?
    let project: String?
    let branch: String?
    let links: [String]
}

struct WorkspaceFilters: Equatable, Sendable {
    var query = ""
    var statuses: Set<WorkspaceStatusKind> = []
    var owners: Set<String> = []
    var repos: Set<String> = []
    var projects: Set<String> = []

    var isEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            statuses.isEmpty && owners.isEmpty && repos.isEmpty && projects.isEmpty
    }

    var categoryCount: Int {
        statuses.count + owners.count + repos.count + projects.count
    }

    func matches(_ item: WorkspaceFilterItem) -> Bool {
        if !statuses.isEmpty, !statuses.contains(item.status) { return false }
        if !owners.isEmpty, item.owner.map({ !owners.contains($0) }) ?? true { return false }
        if !repos.isEmpty, item.repo.map({ !repos.contains($0) }) ?? true { return false }
        if !projects.isEmpty, item.project.map({ !projects.contains($0) }) ?? true { return false }

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return true }
        let haystack = ([item.title, item.owner, item.repo, item.project, item.branch] + item.links)
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(normalizedQuery)
    }

    func removing(status: WorkspaceStatusKind) -> Self {
        var next = self
        next.statuses.remove(status)
        return next
    }

    func removing(owner: String) -> Self {
        var next = self
        next.owners.remove(owner)
        return next
    }

    func removing(repo: String) -> Self {
        var next = self
        next.repos.remove(repo)
        return next
    }

    func removing(project: String) -> Self {
        var next = self
        next.projects.remove(project)
        return next
    }
}

struct WorkspaceTabFilterProjection {
    func visibleItems(
        _ items: [WorkspaceFilterItem],
        filters: WorkspaceFilters
    ) -> [WorkspaceFilterItem] {
        items.filter { filters.matches($0) }
    }

    func values(
        for keyPath: KeyPath<WorkspaceFilterItem, String?>,
        in items: [WorkspaceFilterItem]
    ) -> [String] {
        Set(items.compactMap { $0[keyPath: keyPath] }).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}
