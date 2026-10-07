import Foundation
import ProvenanceEngineContracts
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct WorkspaceCardFilterProjectionTests {
    @Test func projectFilterUsesLinkedProjectRatherThanRepository() throws {
        let first = try fixture(project: "Maple Street Roof", owner: "sam")
        let second = try fixture(project: "Elm Street Inspection", owner: "lee")
        let items = filterItems([first, second])
        #expect(WorkspaceTabFilterProjection().values(for: \.project, in: items) == ["Elm Street Inspection", "Maple Street Roof"])
        var filters = WorkspaceFilters()
        filters.projects = ["Maple Street Roof"]
        #expect(WorkspaceTabFilterProjection().visibleItems(items, filters: filters).map(\.id) == [first.0.id])
        #expect(items.first?.repo == "roof-inspections")
    }

    @Test func ownerFilterUsesPRAuthorRatherThanTicketAssignee() throws {
        let first = try fixture(project: "Maple Street Roof", owner: "sam")
        let second = try fixture(project: "Maple Street Roof", owner: "lee")
        let items = filterItems([first, second])
        #expect(WorkspaceTabFilterProjection().values(for: \.owner, in: items) == ["lee", "sam"])
        var filters = WorkspaceFilters()
        filters.owners = ["sam"]
        filters.projects = ["Maple Street Roof"]
        #expect(WorkspaceTabFilterProjection().visibleItems(items, filters: filters).map(\.id) == [first.0.id])
        #expect(filters.categoryCount == 2)
        #expect(filters.removing(owner: "sam").owners.isEmpty)
    }

    @Test func unlinkedWorkspaceHasNoProjectOrOwnerFilterValue() {
        let workspace = Workspace(title: "Roof inspection")
        workspace.currentDirectory = "/tmp/roof-inspections"
        let item = WorkspaceTabFilterProjection().items(for: [workspace]).first
        #expect(item?.project == nil)
        #expect(item?.owner == nil)
    }

    @Test(arguments: [nil, "  "] as [String?])
    func unnamedProjectsDoNotBecomeIDFilterChoices(title: String?) throws {
        let value = try fixture(project: title, owner: "sam")
        #expect(filterItems([value]).first?.project == nil)
    }

    @Test(arguments: [
        (42, "https://github.com/roof-co/inspections/pull/42", nil, "sam"),
        (42, "https://github.com/other-co/inspections/pull/42", nil, nil),
        (43, "https://github.com/roof-co/inspections/pull/42", nil, nil),
        (42, "https://github.com/roof-co/inspections/pull/42", "lee", "lee"),
    ] as [(Int, String, String?, String?)])
    func ownerFallbackRequiresMatchingPRIdentity(
        number: Int, url: String, nativeOwner: String?, expectedOwner: String?
    ) throws {
        let value = try fixture(project: "Maple Street Roof", owner: "sam", nativeNumber: number,
                                nativeOwner: nativeOwner, nativeURL: URL(string: url))
        #expect(filterItems([value]).first?.owner == expectedOwner)
    }

    @Test func selectedFiltersDoNotChangeWorkspaces() throws {
        let value = try fixture(project: "Maple Street Roof", owner: "sam")
        var filters = WorkspaceFilters()
        filters.owners = ["lee"]
        #expect(WorkspaceTabFilterProjection().visibleItems(filterItems([value]), filters: filters).isEmpty)
        #expect(value.0.title == "Review roof inspection")
        #expect(value.0.customDescription == "Review the flashing photographs")
        #expect(value.1.prompt == "Compare the latest gutter photographs")
    }

    private func filterItems(_ fixtures: [(Workspace, WorkspaceReferenceCardSnapshot)]) -> [WorkspaceFilterItem] {
        WorkspaceTabFilterProjection().items(for: fixtures.map { $0.0 })
    }

    private func fixture(
        project: String?, owner: String, nativeNumber: Int? = nil,
        nativeOwner: String? = nil, nativeURL: URL? = nil
    ) throws -> (Workspace, WorkspaceReferenceCardSnapshot) {
        let workspace = Workspace(title: "Review roof inspection")
        workspace.currentDirectory = "/tmp/roof-inspections"
        workspace.setCustomDescription("Review the flashing photographs")
        if let nativeNumber, let nativeURL {
            workspace.updatePanelPullRequest(
                panelId: try #require(workspace.focusedPanelId), number: nativeNumber, label: "PR",
                url: nativeURL, ownerLogin: nativeOwner, status: .open,
                bindToCurrentBranch: false, source: .promptMention
            )
        }
        let record = ProvenanceWorkspaceDisplayRecord(
            id: "roof-work-\(workspace.id)", workspaceID: workspace.stableId.uuidString,
            title: "Review roof inspection", pullRequestNumber: 42,
            pullRequestURL: "https://github.com/roof-co/inspections/pull/42",
            pullRequestOwnerLogin: owner, pullRequestStatus: "open",
            ticketLinks: [.init(id: "ROOF-42", title: "Repair chimney flashing", ownerName: "Taylor Field")],
            projectLinks: [.init(id: "roof-project", title: project)],
            lastSubmittedPrompt: "Compare the latest gutter photographs",
            observedAt: Date(), updatedAt: Date()
        )
        let provenance = try #require(WorkspaceDisplayCurrentStateSnapshot(record))
        return (workspace, WorkspaceReferenceCardSnapshot(
            workspace: workspace, provenance: provenance, workspaceTitle: workspace.title
        ))
    }
}
