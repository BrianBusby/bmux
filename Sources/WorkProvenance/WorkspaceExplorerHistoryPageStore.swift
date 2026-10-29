import Foundation
import Observation

/// Owns Explorer's bounded historical-workspace cursor and rejects stale pages.
@MainActor @Observable
final class WorkspaceExplorerHistoryPageStore {
    typealias Loader = @MainActor (String) async throws -> WorkspaceExplorerHistoryLoadResult

    private let loader: Loader?
    private var revision = 0
    private var consumedCursors: Set<String> = []
    private var fillTask: Task<Void, Never>?
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    init(loader: Loader?) {
        self.loader = loader
    }

    func reset(cursor: String?) {
        fillTask?.cancel()
        fillTask = nil
        revision &+= 1
        consumedCursors.removeAll()
        nextCursor = loader == nil ? nil : cursor
        isLoading = false
        loadFailed = false
    }

    func loadMore(singlePage: Bool,
                  visibleCount: @escaping @MainActor () -> Int,
                  append: @escaping @MainActor (WorkspaceExplorerHistoryLoadResult) -> Void) async {
        await load(to: visibleCount() + 25, singlePage: singlePage,
            visibleCount: visibleCount, append: append)
    }

    func scheduleFill(needed: Bool,
                      visibleCount: @escaping @MainActor () -> Int,
                      append: @escaping @MainActor (WorkspaceExplorerHistoryLoadResult) -> Void) {
        let previous = fillTask
        previous?.cancel()
        guard needed, visibleCount() < 25, nextCursor != nil else { return }
        fillTask = Task {
            await previous?.value
            await load(to: 25, singlePage: false, visibleCount: visibleCount, append: append)
        }
    }

    func load(to targetVisibleCount: Int, singlePage: Bool,
              visibleCount: @MainActor () -> Int,
              append: @MainActor (WorkspaceExplorerHistoryLoadResult) -> Void) async {
        guard let loader, !isLoading else { return }
        let requestRevision = revision
        isLoading = true
        defer { if revision == requestRevision { isLoading = false } }
        while !Task.isCancelled, revision == requestRevision,
              let cursor = nextCursor, visibleCount() < targetVisibleCount {
            do {
                let page = try await loader(cursor)
                guard !Task.isCancelled, revision == requestRevision,
                      nextCursor == cursor else { return }
                guard page.nextHistoryCursor != cursor,
                      !consumedCursors.contains(cursor) else {
                    loadFailed = true
                    return
                }
                consumedCursors.insert(cursor)
                nextCursor = page.nextHistoryCursor
                append(page)
                loadFailed = false
                if singlePage { return }
            } catch is CancellationError {
                return
            } catch {
                guard revision == requestRevision else { return }
                loadFailed = true
                sentryCaptureError("Workspace Explorer history page load failed", category: "provenance",
                    data: ["error_type": String(reflecting: type(of: error))])
                return
            }
        }
    }
}
