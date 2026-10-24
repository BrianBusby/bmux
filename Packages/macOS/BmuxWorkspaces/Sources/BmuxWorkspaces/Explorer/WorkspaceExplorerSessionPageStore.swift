public import Foundation
public import Observation
public import ProvenanceEngineContracts

/// Owns retained-session pages and rejects responses from superseded requests.
///
/// Inject loaders to test without starting the app.
/// ```swift
/// let store = WorkspaceExplorerSessionPageStore(
///     loadFirst: { id in try await archive.firstPage(for: id) },
///     loadNext: { id, cursor in try await archive.nextPage(for: id, cursor: cursor) })
/// ```
@MainActor @Observable
public final class WorkspaceExplorerSessionPageStore {
    /// Loads the first page for a stable workspace ID.
    public typealias FirstLoader = @MainActor @Sendable (UUID) async throws -> ProvenanceWorkspaceSessionPageResponse
    /// Loads a continuation page for a workspace ID and opaque cursor.
    public typealias NextLoader = @MainActor @Sendable (UUID, String) async throws -> ProvenanceWorkspaceSessionPageResponse

    private let loadFirst: FirstLoader
    private let loadNext: NextLoader
    /// Cached retained-session pages keyed by stable workspace ID.
    public private(set) var pagesByWorkspaceID: [String: ProvenanceWorkspaceSessionPageResponse] = [:]
    /// Workspace IDs whose latest page request failed.
    public private(set) var failedWorkspaceIDs: Set<String> = []
    private var generationByWorkspaceID: [String: Int] = [:]
    private var nextRequestByWorkspaceID: [String: UUID] = [:]
    private var navigationRevision = 0
    private var activeWorkspaceID: String?

    /// Creates a store with injected retained-session loaders.
    /// - Parameters:
    ///   - loadFirst: Loads the first page for a workspace.
    ///   - loadNext: Loads the page after an opaque cursor.
    public init(loadFirst: @escaping FirstLoader, loadNext: @escaping NextLoader) {
        self.loadFirst = loadFirst
        self.loadNext = loadNext
    }

    /// Selects a history item and invalidates responses from earlier navigation.
    /// - Parameter id: Stable workspace ID, or `nil` when leaving history.
    public func activate(_ id: String?) {
        guard activeWorkspaceID != id else { return }
        activeWorkspaceID = id
        navigationRevision &+= 1
    }

    /// Clears cached pages and invalidates outstanding requests.
    public func clear() {
        navigationRevision &+= 1
        activeWorkspaceID = nil
        pagesByWorkspaceID.removeAll()
        failedWorkspaceIDs.removeAll()
        generationByWorkspaceID.removeAll()
        nextRequestByWorkspaceID.removeAll()
    }

    /// Replaces the cached first page if this remains the latest request.
    /// - Parameter id: Stable workspace ID to load.
    public func loadFirstPage(for id: String) async {
        guard let stableID = UUID(uuidString: id) else { return }
        let generation = (generationByWorkspaceID[id] ?? 0) &+ 1
        generationByWorkspaceID[id] = generation
        nextRequestByWorkspaceID[id] = nil
        let revision = navigationRevision
        do {
            let page = try await loadFirst(stableID)
            guard !Task.isCancelled, revision == navigationRevision,
                  generationByWorkspaceID[id] == generation else { return }
            pagesByWorkspaceID[id] = page
            failedWorkspaceIDs.remove(id)
        } catch is CancellationError {
            return
        } catch {
            guard revision == navigationRevision,
                  generationByWorkspaceID[id] == generation else { return }
            failedWorkspaceIDs.insert(id)
        }
    }

    /// Appends a unique continuation page if its cursor remains current.
    /// - Parameter id: Stable workspace ID to load.
    public func loadNextPage(for id: String) async {
        guard let stableID = UUID(uuidString: id),
              let current = pagesByWorkspaceID[id],
              let cursor = current.nextCursor,
              nextRequestByWorkspaceID[id] == nil else { return }
        let requestID = UUID()
        nextRequestByWorkspaceID[id] = requestID
        let revision = navigationRevision
        let generation = generationByWorkspaceID[id]
        defer {
            if nextRequestByWorkspaceID[id] == requestID {
                nextRequestByWorkspaceID[id] = nil
            }
        }
        do {
            let next = try await loadNext(stableID, cursor)
            guard !Task.isCancelled, revision == navigationRevision,
                  generationByWorkspaceID[id] == generation,
                  nextRequestByWorkspaceID[id] == requestID,
                  pagesByWorkspaceID[id]?.nextCursor == cursor,
                  next.workspaceID == current.workspaceID else { return }
            let known = Set(current.sessions.map(\.id))
            pagesByWorkspaceID[id] = ProvenanceWorkspaceSessionPageResponse(
                workspaceID: current.workspaceID,
                sessions: current.sessions + next.sessions.filter { !known.contains($0.id) },
                nextCursor: next.nextCursor,
                totalCount: next.totalCount ?? current.totalCount,
                partialCoverage: current.partialCoverage || next.partialCoverage)
            failedWorkspaceIDs.remove(id)
        } catch is CancellationError {
            return
        } catch {
            guard revision == navigationRevision,
                  nextRequestByWorkspaceID[id] == requestID else { return }
            failedWorkspaceIDs.insert(id)
        }
    }
}
