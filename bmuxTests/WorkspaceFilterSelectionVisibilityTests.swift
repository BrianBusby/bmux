import Foundation
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct WorkspaceFilterSelectionVisibilityTests {
    @Test func duplicateTitleDoesNotMakeFilteredSelectionVisible() {
        let selected = item(status: .waiting)
        let visible = item(status: .active)
        #expect(isHidden(selected, items: [selected, visible], filters: activeFilter()))
    }

    @Test func visibleSelectedWorkspaceHasNoHiddenWarning() {
        let selected = item(status: .active)
        let hidden = item(status: .waiting)
        #expect(!isHidden(selected, items: [hidden, selected], filters: activeFilter()))
    }

    @Test func absentSelectionHasNoHiddenWarning() {
        #expect(!isHidden(nil, items: [item(status: .active)], filters: activeFilter()))
    }

    @Test func emptyFiltersHaveNoHiddenWarning() {
        let selected = item(status: .waiting)
        #expect(!isHidden(selected, items: [selected], filters: WorkspaceFilters()))
    }

    @Test func distinctTitleFilteredSelectionHasHiddenWarning() {
        let selected = item(status: .waiting, title: "Inspect chimney flashing")
        #expect(isHidden(selected, items: [selected, item(status: .active)], filters: activeFilter()))
    }

    private func isHidden(
        _ selected: WorkspaceFilterItem?, items: [WorkspaceFilterItem], filters: WorkspaceFilters
    ) -> Bool {
        WorkspaceTabFilterBar(
            items: items, selectedWorkspaceID: selected?.id, selectedWorkspaceTitle: selected?.title,
            filters: .constant(filters), isPanelPresented: .constant(false)
        ).isSelectionHidden
    }

    private func activeFilter() -> WorkspaceFilters {
        var filters = WorkspaceFilters()
        filters.statuses = [.active]
        return filters
    }

    private func item(
        status: WorkspaceStatusKind, title: String = "Review roof inspection"
    ) -> WorkspaceFilterItem {
        WorkspaceFilterItem(
            id: UUID(), title: title, status: status,
            owner: nil, repo: nil, project: nil, branch: nil, links: []
        )
    }
}
