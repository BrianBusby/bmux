import Foundation
import ProvenanceEngineContracts

/// Reads PE-owned factual coding-agent session projections for agent-session UI.
@MainActor
final class AgentSessionFactualProjectionStore {
    private struct CachedSnapshot {
        let snapshot: ProvenanceFactualSessionProjectionSnapshot
        let lastSuccessfulReadAt: Date
        var isStale: Bool
    }

    let client: any ProvenanceEngineClient
    private let now: @MainActor () -> Date
    private var snapshotsBySessionID: [String: CachedSnapshot] = [:]
    private var latestRequestBySessionID: [String: UUID] = [:]
    private var latestResultBySessionID: [String: AgentSessionFactualProjectionReadResult] = [:]

    init(client: any ProvenanceEngineClient, now: @escaping @MainActor () -> Date = Date.init) {
        self.client = client
        self.now = now
    }

    func snapshot(sessionID rawSessionID: String?) -> AgentSessionFactualProjectionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        guard let cached = snapshotsBySessionID[sessionID] else {
            return .notFound(sessionID: sessionID, reason: nil)
        }
        return cached.isStale ? .stale(cached.snapshot, lastSuccessfulReadAt: cached.lastSuccessfulReadAt) :
            .available(cached.snapshot)
    }

    func refreshedSnapshot(sessionID rawSessionID: String?) async -> AgentSessionFactualProjectionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        let requestID = UUID()
        latestRequestBySessionID[sessionID] = requestID
        do {
            let response = try await client.factualSessionProjection(
                ProvenanceFactualSessionProjectionRequest(sessionID: sessionID, turnLimit: 12)
            )
            guard latestRequestBySessionID[sessionID] == requestID else {
                return latestResultBySessionID[sessionID] ?? snapshot(sessionID: sessionID)
            }
            guard response.sessionID == sessionID,
                  response.snapshot.map({ $0.session.id == sessionID }) ?? true else {
                throw ReadError.sessionMismatch
            }
            let result: AgentSessionFactualProjectionReadResult
            if response.found, let snapshot = response.snapshot {
                snapshotsBySessionID[sessionID] = CachedSnapshot(
                    snapshot: snapshot, lastSuccessfulReadAt: now(), isStale: false
                )
                result = .available(snapshot)
            } else {
                snapshotsBySessionID.removeValue(forKey: sessionID)
                result = .notFound(sessionID: sessionID, reason: response.reason)
            }
            latestResultBySessionID[sessionID] = result
            return result
        } catch {
            guard latestRequestBySessionID[sessionID] == requestID else {
                return latestResultBySessionID[sessionID] ?? snapshot(sessionID: sessionID)
            }
            StartupBreadcrumbLog.append("workProvenance.agentSessionFactualProjection.refreshFailed", fields: [
                "session": sessionID,
                "error": String(describing: error)
            ])
            let result: AgentSessionFactualProjectionReadResult
            if var cached = snapshotsBySessionID[sessionID] {
                cached.isStale = true
                snapshotsBySessionID[sessionID] = cached
                result = .stale(cached.snapshot, lastSuccessfulReadAt: cached.lastSuccessfulReadAt)
            } else {
                result = .failed(sessionID: sessionID)
            }
            latestResultBySessionID[sessionID] = result
            return result
        }
    }

    private enum ReadError: Error {
        case sessionMismatch
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
