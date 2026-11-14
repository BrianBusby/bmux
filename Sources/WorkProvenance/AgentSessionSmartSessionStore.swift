import Foundation
import ProvenanceEngineContracts

/// Reads PE SessionWorkModel data for the React Smart Session surface.
@MainActor
final class AgentSessionSmartSessionStore {
    let client: any ProvenanceEngineClient
    private struct CachedSnapshot {
        let snapshot: AgentSessionSmartSessionSnapshot
        let lastSuccessfulReadAt: Date
        var stale: Bool
    }
    private let now: @MainActor () -> Date
    private var snapshotsBySessionID: [String: CachedSnapshot] = [:]
    private var failedSessionIDs: Set<String> = []
    private var refreshTasksBySessionID: [String: RefreshTaskEntry] = [:]
    private static let semanticReconciliationAttemptLimit = 3

    init(client: any ProvenanceEngineClient, now: @escaping @MainActor () -> Date = Date.init) {
        self.client = client
        self.now = now
    }

    func snapshot(sessionID rawSessionID: String?) -> AgentSessionSmartSessionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        if let entry = refreshTasksBySessionID[sessionID], entry.invalidated {
            return Self.uncertainResult(sessionID: sessionID, cached: entry.priorSnapshot)
        }
        guard let cached = snapshotsBySessionID[sessionID] else {
            return failedSessionIDs.contains(sessionID) ? .failed(sessionID: sessionID) : .notFound(sessionID: sessionID, reason: nil)
        }
        return cached.stale ? .stale(cached.snapshot, lastSuccessfulReadAt: cached.lastSuccessfulReadAt) : .available(cached.snapshot)
    }

    func refreshedSnapshot(sessionID rawSessionID: String?) async -> AgentSessionSmartSessionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        if var entry = refreshTasksBySessionID[sessionID] {
            entry.invalidated = true
            refreshTasksBySessionID[sessionID] = entry
            return Self.uncertainResult(sessionID: sessionID, cached: entry.priorSnapshot)
        }
        let priorSnapshot = snapshotsBySessionID[sessionID]
        let requestID = UUID()
        let task = Task { @MainActor in
            await self.loadSnapshot(sessionID: sessionID)
        }
        refreshTasksBySessionID[sessionID] = RefreshTaskEntry(id: requestID, task: task, priorSnapshot: priorSnapshot)
        let result = await task.value
        if let entry = refreshTasksBySessionID[sessionID], entry.id == requestID {
            if entry.invalidated {
                if var prior = entry.priorSnapshot {
                    prior.stale = true
                    snapshotsBySessionID[sessionID] = prior
                } else {
                    snapshotsBySessionID.removeValue(forKey: sessionID)
                    failedSessionIDs.insert(sessionID)
                }
                refreshTasksBySessionID.removeValue(forKey: sessionID)
                return Self.uncertainResult(sessionID: sessionID, cached: entry.priorSnapshot)
            }
            refreshTasksBySessionID.removeValue(forKey: sessionID)
        }
        return result
    }

    private func loadSnapshot(sessionID: String) async -> AgentSessionSmartSessionReadResult {
        do {
            var notFoundReason: String?
            var workModel: ProvenanceSessionWorkModel?
            for attempt in 1...Self.semanticReconciliationAttemptLimit {
                let materialization = await materializeSemanticInferences(sessionID: sessionID)
                let response = try await client.sessionWorkModel(
                    ProvenanceSessionWorkModelRequest(sessionID: sessionID, turnLimit: 12)
                )
                guard response.sessionID == sessionID,
                      response.found == (response.model != nil),
                      response.model.map({ $0.identity.session.id == sessionID &&
                          $0.basis.factualSessionProjection.session.id == sessionID }) ?? true else {
                    throw ReadError.inconsistentResponse
                }
                guard response.found, let responseModel = response.model else {
                    notFoundReason = response.reason
                    workModel = nil
                    break
                }
                workModel = responseModel
                guard Self.needsSemanticReconciliation(materialization: materialization, workModel: responseModel) else {
                    break
                }
                if attempt == Self.semanticReconciliationAttemptLimit {
                    StartupBreadcrumbLog.append(
                        "workProvenance.agentSessionSmartSession.semanticReconciliationLimitReached",
                        fields: [
                            "session": sessionID,
                            "materializedFactualRevision": materialization?.factualRevision.map(String.init) ?? "none",
                            "modelFactualRevision": responseModel.revision.factualRevision.map(String.init) ?? "none"
                        ]
                    )
                }
            }
            guard let workModel else {
                snapshotsBySessionID.removeValue(forKey: sessionID)
                failedSessionIDs.remove(sessionID)
                return .notFound(sessionID: sessionID, reason: notFoundReason)
            }
            let semanticMessages = await presentationMessages(for: workModel)
            let relatedResult = await relatedSessions(sessionID: sessionID)
            let collisionResult = await artifactCollisions(sessionID: sessionID)
            let awareness = AgentSessionSmartSessionSnapshot.CrossSessionAwareness(
                related: relatedResult,
                collisions: collisionResult
            )
            let nextSnapshot = AgentSessionSmartSessionSnapshot(
                workModel: workModel,
                semanticMessages: semanticMessages,
                crossSessionAwareness: awareness
            )
            if let existing = snapshotsBySessionID[sessionID],
               existing.snapshot.revision.isNewerThan(nextSnapshot.revision) ||
                (!nextSnapshot.revision.isNewerThan(existing.snapshot.revision) && !existing.snapshot.hasSamePrimaryContent(as: nextSnapshot)) {
                var stale = existing
                stale = CachedSnapshot(snapshot: existing.snapshot.withAwareness(nextSnapshot.crossSessionAwareness),
                                       lastSuccessfulReadAt: existing.lastSuccessfulReadAt, stale: true)
                snapshotsBySessionID[sessionID] = stale
                return .stale(stale.snapshot, lastSuccessfulReadAt: stale.lastSuccessfulReadAt)
            }
            snapshotsBySessionID[sessionID] = CachedSnapshot(snapshot: nextSnapshot, lastSuccessfulReadAt: now(), stale: false)
            failedSessionIDs.remove(sessionID)
            return .available(nextSnapshot)
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionSmartSession.refreshFailed", fields: [
                "session": sessionID,
                "error": String(describing: error)
            ])
            if var cached = snapshotsBySessionID[sessionID] {
                cached.stale = true
                snapshotsBySessionID[sessionID] = cached
                return .stale(cached.snapshot, lastSuccessfulReadAt: cached.lastSuccessfulReadAt)
            }
            failedSessionIDs.insert(sessionID)
            return .failed(sessionID: sessionID)
        }
    }

    private func relatedSessions(sessionID: String) async -> ProvenanceRelatedSessionResponse? {
        do {
            let response = try await client.relatedSessions(ProvenanceRelatedSessionRequest(
                targetSessionID: sessionID, limit: 5, exclusionLimit: 5
            ))
            guard response.found, response.targetSessionID == sessionID,
                  let projection = response.projection, projection.targetSessionID == sessionID,
                  projection.targetSession.id == sessionID else { throw ReadError.inconsistentResponse }
            return response
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionSmartSession.relatedSessionsSkipped", fields: [
                "session": sessionID, "error": String(describing: error)
            ])
            return nil
        }
    }

    private func artifactCollisions(sessionID: String) async -> ProvenanceArtifactCollisionResponse? {
        do {
            let response = try await client.artifactCollisions(ProvenanceArtifactCollisionRequest(
                targetSessionID: sessionID, limit: 5, relatedSessionLimit: 20, exclusionLimit: 5
            ))
            guard response.found, response.targetSessionID == sessionID,
                  let projection = response.projection, projection.targetSessionID == sessionID,
                  projection.targetSession.id == sessionID else { throw ReadError.inconsistentResponse }
            return response
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionSmartSession.artifactCollisionsSkipped", fields: [
                "session": sessionID, "error": String(describing: error)
            ])
            return nil
        }
    }

    private func materializeSemanticInferences(
        sessionID: String
    ) async -> ProvenanceCodingAgentSessionSemanticInferenceResponse? {
        do {
            return try await client.publishCodingAgentSessionSemanticInferences(
                ProvenanceCodingAgentSessionSemanticInferenceRequest(
                    sessionID: sessionID,
                    turnLimit: 12,
                    createdAt: Date()
                )
            )
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionSmartSession.semanticInferenceSkipped", fields: [
                "session": sessionID,
                "error": String(describing: error)
            ])
            return nil
        }
    }

    private static func needsSemanticReconciliation(
        materialization: ProvenanceCodingAgentSessionSemanticInferenceResponse?,
        workModel: ProvenanceSessionWorkModel
    ) -> Bool {
        guard let materializedRevision = materialization?.factualRevision,
              let modelRevision = workModel.revision.factualRevision else {
            return false
        }
        return modelRevision > materializedRevision
    }

    private func presentationMessages(
        for workModel: ProvenanceSessionWorkModel
    ) async -> [ProvenanceSemanticMessageRecord] {
        do {
            return try await semanticMessages(for: workModel.basis.factualSessionProjection)
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionSmartSession.semanticMessagesSkipped", fields: [
                "session": workModel.identity.session.id,
                "error": String(describing: error)
            ])
            return []
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

    private static func uncertainResult(sessionID: String, cached: CachedSnapshot?) -> AgentSessionSmartSessionReadResult {
        guard let cached else { return .failed(sessionID: sessionID) }
        return .stale(cached.snapshot, lastSuccessfulReadAt: cached.lastSuccessfulReadAt)
    }

    private enum ReadError: Error { case inconsistentResponse }

    private struct SemanticMessageSubject: Hashable {
        let scope: ProvenanceSemanticInferenceScope
        let scopeID: String
    }

    private struct RefreshTaskEntry {
        let id: UUID
        let task: Task<AgentSessionSmartSessionReadResult, Never>
        let priorSnapshot: CachedSnapshot?
        var invalidated = false
    }
}
