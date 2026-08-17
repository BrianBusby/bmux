import Foundation
import ProvenanceEngineContracts

/// Reads PE-owned factual coding-agent session projections for agent-session UI.
@MainActor
final class AgentSessionFactualProjectionStore {
    private let client: any ProvenanceEngineClient
    private var snapshotsBySessionID: [String: ProvenanceFactualSessionProjectionSnapshot] = [:]

    init(client: any ProvenanceEngineClient) {
        self.client = client
    }

    func snapshot(sessionID rawSessionID: String?) -> AgentSessionFactualProjectionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        guard let snapshot = snapshotsBySessionID[sessionID] else {
            return .notFound(sessionID: sessionID, reason: nil)
        }
        return .available(snapshot)
    }

    func refreshedSnapshot(sessionID rawSessionID: String?) async -> AgentSessionFactualProjectionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        do {
            let response = try await client.factualSessionProjection(
                ProvenanceFactualSessionProjectionRequest(sessionID: sessionID, turnLimit: 12)
            )
            guard response.found, let snapshot = response.snapshot else {
                snapshotsBySessionID.removeValue(forKey: sessionID)
                return .notFound(sessionID: sessionID, reason: response.reason)
            }
            snapshotsBySessionID[sessionID] = snapshot
            return .available(snapshot)
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionFactualProjection.refreshFailed", fields: [
                "session": sessionID,
                "error": String(describing: error)
            ])
            if let snapshot = snapshotsBySessionID[sessionID] {
                return .available(snapshot)
            }
            return .failed(sessionID: sessionID)
        }
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
