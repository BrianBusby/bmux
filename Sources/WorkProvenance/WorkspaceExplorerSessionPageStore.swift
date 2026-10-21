import Foundation
import Observation
import ProvenanceEngineContracts

/// Owns retained-session pages and rejects responses from superseded requests.
@MainActor @Observable
final class WorkspaceExplorerSessionPageStore {
    typealias FirstLoader = @MainActor (UUID) async throws -> ProvenanceWorkspaceSessionPageResponse
    typealias NextLoader = @MainActor (UUID, String) async throws -> ProvenanceWorkspaceSessionPageResponse

    private let loadFirst: FirstLoader
    private let loadNext: NextLoader
    private(set) var pagesByWorkspaceID: [String: ProvenanceWorkspaceSessionPageResponse] = [:]
    private(set) var failedWorkspaceIDs: Set<String> = []
    private var generationByWorkspaceID: [String: Int] = [:]
    private var nextRequestByWorkspaceID: [String: UUID] = [:]
    private var navigationRevision = 0
    private var activeWorkspaceID: String?

    init(loadFirst: @escaping FirstLoader, loadNext: @escaping NextLoader) {
        self.loadFirst = loadFirst
        self.loadNext = loadNext
    }

    func activate(_ id: String?) {
        guard activeWorkspaceID != id else { return }
        activeWorkspaceID = id
        navigationRevision &+= 1
    }

    func clear() {
        navigationRevision &+= 1
        activeWorkspaceID = nil
        pagesByWorkspaceID.removeAll()
        failedWorkspaceIDs.removeAll()
        generationByWorkspaceID.removeAll()
        nextRequestByWorkspaceID.removeAll()
    }

    func loadFirstPage(for id: String) async {
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

    func loadNextPage(for id: String) async {
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
