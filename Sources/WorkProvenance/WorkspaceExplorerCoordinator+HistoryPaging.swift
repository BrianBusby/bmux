import Foundation

/// Bridges Explorer navigation and filtering to the retained-history page store.
@MainActor
extension WorkspaceExplorerCoordinator {
    var hasMoreHistory: Bool { historyPages.nextCursor != nil }

    func loadMoreHistoryPage() async {
        guard !isStopped else { return }
        await historyPages.loadMore(singlePage: activeArrangement.filters.isEmpty && scope.period == .anyTime &&
            collectionTarget == nil,
            visibleCount: { [weak self] in self?.visibleHistoricalCount() ?? 0 },
            append: { [weak self] in self?.appendHistoryPage($0) })
    }

    func scheduleHistoryFill() {
        historyPages.scheduleFill(needed: !isStopped && scope.state != .open &&
            (!activeArrangement.filters.isEmpty || scope.period != .anyTime || collectionTarget != nil),
            visibleCount: { [weak self] in self?.visibleHistoricalCount() ?? 0 },
            append: { [weak self] in self?.appendHistoryPage($0) })
    }

    private func appendHistoryPage(_ page: WorkspaceExplorerHistoryLoadResult) {
        guard let lastLoadResult else { return }
        present(lastLoadResult.appendingHistoryPage(page), preserveObservedStatuses: true)
    }

    private func visibleHistoricalCount() -> Int {
        guard let catalog else { return 0 }
        let visibleIDs = Set(catalog.project(target: collectionTarget ?? .all, scope: scope,
            arrangement: activeArrangement, now: activityClock.now,
            calendar: activityClock.calendar)?.visibleWorkspaceIDs ?? [])
        return catalog.items.filter { !$0.isOpen && visibleIDs.contains($0.id) }.count
    }
}
