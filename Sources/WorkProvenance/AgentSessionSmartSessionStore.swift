import Foundation
import ProvenanceEngineContracts

/// Reads PE factual and semantic presentation data for the React Smart Session surface.
@MainActor
final class AgentSessionSmartSessionStore {
    private let client: any ProvenanceEngineClient
    private var snapshotsBySessionID: [String: AgentSessionSmartSessionSnapshot] = [:]

    init(client: any ProvenanceEngineClient) {
        self.client = client
    }

    func snapshot(sessionID rawSessionID: String?) -> AgentSessionSmartSessionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        guard let snapshot = snapshotsBySessionID[sessionID] else {
            return .notFound(sessionID: sessionID, reason: nil)
        }
        return .available(snapshot)
    }

    func refreshedSnapshot(sessionID rawSessionID: String?) async -> AgentSessionSmartSessionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        do {
            let response = try await client.factualSessionProjection(
                ProvenanceFactualSessionProjectionRequest(sessionID: sessionID, turnLimit: 12)
            )
            guard response.found, let factualProjection = response.snapshot else {
                snapshotsBySessionID.removeValue(forKey: sessionID)
                return .notFound(sessionID: sessionID, reason: response.reason)
            }
            let semanticMessages = try await semanticMessages(for: factualProjection)
            let nextSnapshot = AgentSessionSmartSessionSnapshot(
                factualProjection: factualProjection,
                semanticMessages: semanticMessages
            )
            if let existing = snapshotsBySessionID[sessionID],
               existing.revision.isNewerThan(nextSnapshot.revision) {
                return .available(existing)
            }
            snapshotsBySessionID[sessionID] = nextSnapshot
            return .available(nextSnapshot)
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionSmartSession.refreshFailed", fields: [
                "session": sessionID,
                "error": String(describing: error)
            ])
            if let snapshot = snapshotsBySessionID[sessionID] {
                return .available(snapshot)
            }
            return .failed(sessionID: sessionID)
        }
    }

    private func semanticMessages(
        for factualProjection: ProvenanceFactualSessionProjectionSnapshot
    ) async throws -> [ProvenanceSemanticMessageRecord] {
        var recordsByID: [String: ProvenanceSemanticMessageRecord] = [:]
        for subject in Self.semanticMessageSubjects(for: factualProjection) {
            let response = try await client.semanticMessages(
                ProvenanceSemanticMessageQueryRequest(
                    scope: subject.scope,
                    scopeID: subject.scopeID,
                    includeInactive: false,
                    limit: 20
                )
            )
            for record in response.records where record.status == .active {
                recordsByID[record.id] = record
            }
        }
        return recordsByID.values.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id < $1.id
        }
    }

    private static func semanticMessageSubjects(
        for factualProjection: ProvenanceFactualSessionProjectionSnapshot
    ) -> [SemanticMessageSubject] {
        var subjects: [SemanticMessageSubject] = [
            SemanticMessageSubject(scope: .session, scopeID: factualProjection.session.id)
        ]
        for identity in factualProjection.providerThreadIdentities {
            subjects.append(SemanticMessageSubject(scope: .thread, scopeID: identity.threadID))
        }
        let turns = factualProjection.turns.map(\.turn.id)
        for turnID in turns {
            subjects.append(SemanticMessageSubject(scope: .turn, scopeID: turnID))
        }
        var seen: Set<SemanticMessageSubject> = []
        return subjects.filter { subject in
            guard !seen.contains(subject) else { return false }
            seen.insert(subject)
            return true
        }
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private struct SemanticMessageSubject: Hashable {
        let scope: ProvenanceSemanticInferenceScope
        let scopeID: String
    }
}
