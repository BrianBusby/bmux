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
    private static let admittedWaiterLimit = 16

    #if DEBUG
    enum RefreshObservation: Equatable, Sendable {
        case admitted(sessionID: String, followingUp: Bool)
        case cancelled(sessionID: String, followingUp: Bool)
        case rejected(sessionID: String, followingUp: Bool)
    }
    private let refreshObserver: (@MainActor (RefreshObservation) -> Void)?

    init(client: any ProvenanceEngineClient, now: @escaping @MainActor () -> Date = Date.init,
         refreshObserver: (@MainActor (RefreshObservation) -> Void)? = nil) {
        self.client = client
        self.now = now
        self.refreshObserver = refreshObserver
    }
    #else
    init(client: any ProvenanceEngineClient, now: @escaping @MainActor () -> Date = Date.init) {
        self.client = client
        self.now = now
    }
    #endif

    func snapshot(sessionID rawSessionID: String?) -> AgentSessionSmartSessionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        if let entry = refreshTasksBySessionID[sessionID], entry.followingUp || entry.overflowDirty || !entry.dirtyWaiters.isEmpty {
            return Self.uncertainResult(sessionID: sessionID, cached: entry.priorSnapshot)
        }
        guard let cached = snapshotsBySessionID[sessionID] else {
            return failedSessionIDs.contains(sessionID) ? .failed(sessionID: sessionID) : .notFound(sessionID: sessionID, reason: nil)
        }
        return cached.stale ? .stale(cached.snapshot, lastSuccessfulReadAt: cached.lastSuccessfulReadAt) : .available(cached.snapshot)
    }

    func refreshedSnapshot(sessionID rawSessionID: String?) async -> AgentSessionSmartSessionReadResult {
        guard let sessionID = Self.trimmedNonEmpty(rawSessionID) else { return .missingSession }
        let waiterID = UUID()
        return await withTaskCancellationHandler {
            guard !Task.isCancelled else { return .failed(sessionID: sessionID) }
            let task: Task<AgentSessionSmartSessionReadResult, Never>
            if var entry = refreshTasksBySessionID[sessionID] {
                guard entry.admittedWaiters.count < Self.admittedWaiterLimit else {
                    entry.overflowDirty = true
                    refreshTasksBySessionID[sessionID] = entry
                    #if DEBUG
                    refreshObserver?(.rejected(sessionID: sessionID, followingUp: entry.followingUp))
                    #endif
                    return Self.uncertainResult(sessionID: sessionID, cached: entry.priorSnapshot)
                }
                entry.admittedWaiters.insert(waiterID)
                entry.dirtyWaiters.insert(waiterID)
                refreshTasksBySessionID[sessionID] = entry
                #if DEBUG
                refreshObserver?(.admitted(sessionID: sessionID, followingUp: entry.followingUp))
                #endif
                task = entry.task
            } else {
                let requestID = UUID()
                let priorSnapshot = snapshotsBySessionID[sessionID]
                task = Task { @MainActor in
                    await self.performRefresh(sessionID: sessionID, requestID: requestID)
                }
                refreshTasksBySessionID[sessionID] = RefreshTaskEntry(
                    id: requestID, task: task, priorSnapshot: priorSnapshot
                )
            }
            let result = await task.value
            return Task.isCancelled ? .failed(sessionID: sessionID) : result
        } onCancel: {
            Task { @MainActor in self.cancelWaiter(waiterID, sessionID: sessionID) }
        }
    }

    private func cancelWaiter(_ waiterID: UUID, sessionID: String) {
        guard var entry = refreshTasksBySessionID[sessionID] else { return }
        entry.dirtyWaiters.remove(waiterID)
        let wasAdmitted = entry.admittedWaiters.remove(waiterID) != nil
        refreshTasksBySessionID[sessionID] = entry
        #if DEBUG
        if wasAdmitted { refreshObserver?(.cancelled(sessionID: sessionID, followingUp: entry.followingUp)) }
        #else
        _ = wasAdmitted
        #endif
    }

    private func performRefresh(sessionID: String, requestID: UUID) async -> AgentSessionSmartSessionReadResult {
        let firstResult = await loadSnapshot(sessionID: sessionID)
        guard var entry = refreshTasksBySessionID[sessionID], entry.id == requestID else { return firstResult }
        guard entry.overflowDirty || !entry.dirtyWaiters.isEmpty else {
            refreshTasksBySessionID.removeValue(forKey: sessionID)
            return firstResult
        }
        entry.followingUp = true
        entry.dirtyWaiters.removeAll()
        entry.overflowDirty = false
        refreshTasksBySessionID[sessionID] = entry
        let secondResult = await loadSnapshot(sessionID: sessionID)
        guard let finalEntry = refreshTasksBySessionID[sessionID], finalEntry.id == requestID else { return secondResult }
        if finalEntry.overflowDirty || !finalEntry.dirtyWaiters.isEmpty {
            if var prior = finalEntry.priorSnapshot {
                prior.stale = true
                snapshotsBySessionID[sessionID] = prior
            } else {
                snapshotsBySessionID.removeValue(forKey: sessionID)
                failedSessionIDs.insert(sessionID)
            }
            refreshTasksBySessionID.removeValue(forKey: sessionID)
            return Self.uncertainResult(sessionID: sessionID, cached: finalEntry.priorSnapshot)
        }
        refreshTasksBySessionID.removeValue(forKey: sessionID)
        return secondResult
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
                semanticMessages: semanticMessages ?? [],
                semanticMessagesReadStatus: semanticMessages == nil ? "unavailable" : "available",
                crossSessionAwareness: awareness
            )
            if let existing = snapshotsBySessionID[sessionID],
               existing.snapshot.revision.isNewerThan(nextSnapshot.revision) ||
                (!nextSnapshot.revision.isNewerThan(existing.snapshot.revision) &&
                 !existing.snapshot.hasSamePrimaryContent(as: nextSnapshot) &&
                 !existing.snapshot.canRecoverMissingMessages(from: nextSnapshot)) {
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
    ) async -> [ProvenanceSemanticMessageRecord]? {
        do {
            return try await semanticMessages(for: workModel.basis.factualSessionProjection)
        } catch {
            StartupBreadcrumbLog.append("workProvenance.agentSessionSmartSession.semanticMessagesSkipped", fields: [
                "session": workModel.identity.session.id,
                "error": String(describing: error)
            ])
            return nil
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
            guard response.records.allSatisfy({ $0.scope == subject.scope && $0.scopeID == subject.scopeID }) else {
                throw ReadError.inconsistentResponse
            }
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
        var followingUp = false
        var overflowDirty = false
        var admittedWaiters: Set<UUID> = []
        var dirtyWaiters: Set<UUID> = []
    }
}
