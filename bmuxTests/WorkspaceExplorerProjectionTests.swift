import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkspaceExplorerProjectionTests {
    private let now = Date(timeIntervalSince1970: 1_792_521_000)
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func scopeAndUniqueCountsAcrossProjects() {
        let shared = workspace("shared", projects: ["p1", "p3"], ago: 60)
        let first = workspace("first", projects: ["p1"], ago: 10)
        let closed = workspace("closed", projects: ["p5"], ago: 90, closed: true)
        let old = workspace("old", projects: ["p1"], ago: 1_500)
        let unassigned = workspace("scratch", projects: [], ago: 5)
        let projection = WorkspaceExplorerProjection(projects: projects,
            workspaces: [shared, first, closed, old, unassigned], archiveAvailable: true)
        let open = projection.overview(scope: .init(state: .open, period: .last24Hours),
            groupBy: [], filters: [:], now: now, calendar: calendar)
        #expect(open.counts.workspaces == 3)
        #expect(open.inScopeProjectIDs == ["p1", "p3"])
        let all = projection.overview(scope: .init(state: .all, period: .last24Hours),
            groupBy: [.projectOwner], filters: [:], now: now, calendar: calendar)
        #expect(all.counts.workspaces == 4)
        #expect(all.counts.open == 3)
        #expect(all.counts.closed == 1)
        #expect(all.inScopeProjectIDs == ["p1", "p3", "p5"])
        let closedOnly = projection.collection(target: .project("p5"),
            scope: .init(state: .closed, period: .last24Hours), groupBy: [], filters: [:],
            now: now, calendar: calendar)
        #expect(closedOnly.inScopeWorkspaceIDs == ["closed"])
        var localCalendar = calendar
        localCalendar.timeZone = TimeZone(secondsFromGMT: -4 * 3_600) ?? .current
        let today = WorkspaceExplorerScope(state: .all, period: .today)
        #expect(today.includes(first, now: now, calendar: localCalendar))
        #expect(!today.includes(old, now: now, calendar: localCalendar))
    }

    @Test
    func filtersIntersectAndMissingBucketsStayVisible() {
        let brian = workspace("brian", projects: ["p1"], ago: 5, prOwner: "Brian")
        let ada = workspace("ada", projects: ["p1"], ago: 10, prOwner: "Ada")
        let unknown = workspace("unknown", projects: ["p1"], ago: 20, hasPR: true)
        let noPR = workspace("none", projects: ["p1"], ago: 30)
        let projection = WorkspaceExplorerProjection(projects: projects,
            workspaces: [brian, ada, unknown, noPR], archiveAvailable: true)
        let result = projection.collection(target: .project("p1"), scope: .init(),
            groupBy: [.repository, .pullRequestOwner, .bmuxStatus],
            filters: [.repository: .value("bmux"), .pullRequestOwner: .value("Brian")],
            now: now, calendar: calendar)
        #expect(result.counts.workspaces == 4)
        #expect(result.visibleWorkspaceIDs == ["brian"])
        let all = projection.collection(target: .project("p1"), scope: .init(), groupBy: [.pullRequestOwner],
            filters: [:], now: now, calendar: calendar)
        #expect(all.groups.compactMap(\.value) == ["Ada", "Brian", "No PR", "Unknown PR owner"])
    }

    @Test
    func overviewMatchCountDoesNotShrinkProjectCardCount() {
        let input = workspace("input", projects: ["p1"], ago: 5, status: .needsInput)
        let idle = workspace("idle", projects: ["p1"], ago: 10)
        let projection = WorkspaceExplorerProjection(projects: projects,
            workspaces: [input, idle], archiveAvailable: true)
        let result = projection.overview(scope: .init(), groupBy: [],
            filters: [.bmuxStatus: .bmuxStatus(.needsInput)], now: now, calendar: calendar)
        #expect(result.visibleProjectIDs == ["p1"])
        #expect(result.matchingWorkspacesByProjectID["p1"] == 1)
        #expect(result.groups.first?.counts.workspaces == 2)
    }

    @Test
    func unavailableArchiveLeavesClosedCountUnknown() {
        let open = workspace("open", projects: ["p1"], ago: 5)
        let projection = WorkspaceExplorerProjection(projects: projects, workspaces: [open], archiveAvailable: false)
        let result = projection.collection(target: .project("p1"), scope: .init(state: .all, period: .anyTime),
            groupBy: [], filters: [:], now: now, calendar: calendar)
        #expect(result.counts.open == 1)
        #expect(!result.counts.closedKnown)
    }

    @Test
    func duplicateLogicalIDPrefersLivePresence() {
        let archived = workspace("reopened", projects: ["p5"], ago: 90, closed: true)
        let live = workspace("reopened", projects: ["p5"], ago: 5)
        let projection = WorkspaceExplorerProjection(projects: projects,
            workspaces: [archived, live], archiveAvailable: true)
        let result = projection.collection(target: .project("p5"), scope: .init(),
            groupBy: [], filters: [:], now: now, calendar: calendar)
        #expect(result.inScopeWorkspaceIDs == ["reopened"])
        #expect(result.counts.open == 1)
    }

    @Test
    func statusMembershipWaitsForExplicitArrangementUpdate() {
        var statuses = WorkspaceExplorerStatusArrangement()
        statuses.observe(workspaceID: "w", status: .running, groupBy: [.bmuxStatus], filters: [:])
        statuses.observe(workspaceID: "w", status: .needsInput, groupBy: [.bmuxStatus], filters: [:])
        #expect(statuses.liveStatus(for: "w") == .needsInput)
        #expect(statuses.arrangedStatus(for: "w") == .running)
        #expect(statuses.pendingWorkspaceIDs == ["w"])
        statuses.applyPending()
        #expect(statuses.pendingWorkspaceIDs.isEmpty)
    }

    @Test
    func undoLeavesCollapseScrollAndSelectionAlone() {
        var view = WorkspaceExplorerViewArrangement()
        view.scrollOffset = 250
        view.selectedWorkspaceID = "w"
        view.setGroupBy([.repository, .ticket])
        view.setFilter(.ticket, value: .value("INP-2410"))
        view.toggleCollapsed("repo=bmux")
        view.undo()
        #expect(view.groupBy == [.repository, .ticket])
        #expect(view.filters.isEmpty)
        #expect(view.collapsedPaths.contains("repo=bmux"))
        #expect(view.scrollOffset == 250)
        #expect(view.selectedWorkspaceID == "w")
    }

    @Test
    func denseThreeLevelGroupingRetainsFortyUniqueCards() {
        let dense = (0..<40).map { index in
            workspace("dense-\(index)", projects: [index.isMultiple(of: 2) ? "p1" : "p3"],
                ago: Double(index * 37), closed: index.isMultiple(of: 4),
                prOwner: index.isMultiple(of: 5) ? nil : "Brian", hasPR: true,
                status: index.isMultiple(of: 3) ? .needsInput : .running)
        }
        let projection = WorkspaceExplorerProjection(projects: projects,
            workspaces: dense, archiveAvailable: true)
        let result = projection.collection(target: .all,
            scope: .init(state: .all, period: .anyTime),
            groupBy: [.project, .pullRequestOwner, .bmuxStatus, .ticket],
            filters: [:], now: now, calendar: calendar)
        #expect(result.counts.workspaces == 40)
        #expect(result.counts.closed == 10)
        #expect(result.groups.allSatisfy { $0.children.allSatisfy {
            $0.children.allSatisfy { $0.children.first?.dimension == nil }
        } })
    }

    @Test
    func projectGroupingAndFocusUseProjectIdentityWhenNamesMatch() {
        let namesakes = [
            WorkspaceExplorerProject(id: "p1", name: "Review", owner: nil, status: nil),
            WorkspaceExplorerProject(id: "p2", name: "Review", owner: nil, status: nil),
        ]
        let projection = WorkspaceExplorerProjection(projects: namesakes, workspaces: [
            workspace("one", projects: ["p1"], ago: 1),
            workspace("two", projects: ["p2"], ago: 1),
            workspace("shared", projects: ["p1", "p2"], ago: 1),
            workspace("scratch", projects: [], ago: 1),
        ], archiveAvailable: true)
        let grouped = projection.collection(target: .all, scope: .init(), groupBy: [.project],
            filters: [:], now: now, calendar: calendar)
        #expect(grouped.groups.count == 4)
        let focused = projection.collection(target: .all, scope: .init(), groupBy: [.project],
            filters: [.project: .project("p1")], now: now, calendar: calendar)
        #expect(focused.visibleWorkspaceIDs == ["one"])
        #expect(Set(grouped.groups.compactMap(\.filterValue)) == [.project("p1"), .project("p2"), .unassigned])
        let unassigned = projection.collection(target: .all, scope: .init(), groupBy: [.project],
            filters: [.project: .unassigned], now: now, calendar: calendar)
        #expect(unassigned.visibleWorkspaceIDs == ["scratch"])
    }

    @Test
    func missingRepositoryBucketDoesNotMergeWithNamedRepository() {
        let projection = WorkspaceExplorerProjection(projects: projects, workspaces: [
            workspace("missing", projects: ["p1"], ago: 1, repository: nil),
            workspace("named", projects: ["p1"], ago: 1, repository: "Unknown repository"),
        ], archiveAvailable: true)
        let grouped = projection.collection(target: .project("p1"), scope: .init(),
            groupBy: [.repository], filters: [:], now: now, calendar: calendar)
        #expect(grouped.groups.count == 2)
        #expect(Set(grouped.groups.flatMap(\.workspaceIDs)) == ["missing", "named"])
        let focused = projection.collection(target: .project("p1"), scope: .init(),
            groupBy: [.repository], filters: [.repository: .missing("Unknown repository")],
            now: now, calendar: calendar)
        #expect(focused.visibleWorkspaceIDs == ["missing"])
    }

    private var projects: [WorkspaceExplorerProject] {
        [.init(id: "p1", name: "Session experience", owner: "Brian", status: "Active"),
         .init(id: "p3", name: "Review workflow", owner: "Brian", status: "Planning"),
         .init(id: "p5", name: "Provenance import", owner: "Luis", status: "Done")]
    }

    private func workspace(_ id: String, projects: [String], ago: TimeInterval,
        repository: String? = "bmux",
        closed: Bool = false, prOwner: String? = nil, hasPR: Bool = false,
        status: WorkspaceExplorerStatus = .idle) -> WorkspaceExplorerWorkspace {
        WorkspaceExplorerWorkspace(id: id, title: id, projectIDs: projects, repository: repository,
            tickets: [], ticketStatus: nil, pullRequestOwner: prOwner, pullRequestStatus: nil,
            hasPullRequest: hasPR || prOwner != nil, lastActivityAt: now.addingTimeInterval(-ago * 60),
            isClosed: closed, liveStatus: status, arrangedStatus: status)
    }
}
