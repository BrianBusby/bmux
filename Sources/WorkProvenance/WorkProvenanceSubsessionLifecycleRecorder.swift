import Foundation

/// Persists observed agent subsession lifecycle changes into WorkProvenance.
actor WorkProvenanceSubsessionLifecycleRecorder {
    private let store: WorkProvenanceStore
    private let stableIDFactory: WorkProvenanceStableIDFactory
    private let observabilityStore: ProvenanceObservabilityStore?
    private let awaitObservabilityWrites: Bool
    private let traceNow: @Sendable () -> Date

    /// Last persistence error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates a lifecycle recorder.
    init(
        store: WorkProvenanceStore,
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory(),
        observabilityStore: ProvenanceObservabilityStore? = nil,
        awaitObservabilityWrites: Bool = false,
        traceNow: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.stableIDFactory = stableIDFactory
        self.observabilityStore = observabilityStore
        self.awaitObservabilityWrites = awaitObservabilityWrites
        self.traceNow = traceNow
    }

    /// Records a lifecycle change, keeping provenance persistence best-effort.
    func record(_ change: AgentSubsessionLifecycleChange, timestamp: Date) async {
        let pipelineRunID = UUID().uuidString
        let runStartedAt = traceNow()
        var stages: [ProvenancePipelineStageExecutionRecord] = []
        var builtWorkProvenanceEvent: WorkProvenanceEvent?
        var identityResolution: LifecycleIdentityResolution?
        do {
            let receivedStartedAt = traceNow()
            let resolutionStartedAt = traceNow()
            let identity = lifecycleIdentity(for: change)
            let builtEvent = try await event(for: change, timestamp: timestamp, identity: identity)
            let resolutionEndedAt = traceNow()
            identityResolution = (
                identity: identity,
                startedAt: resolutionStartedAt,
                endedAt: resolutionEndedAt
            )
            let receivedEndedAt = traceNow()
            builtWorkProvenanceEvent = builtEvent
            stages.append(stageRecord(
                pipelineRunID: pipelineRunID,
                stageName: "lifecycle_change_received",
                status: "succeeded",
                startedAt: receivedStartedAt,
                endedAt: receivedEndedAt,
                inputCount: 1,
                outputCount: 1,
                errorSummary: nil
            ))
            let appendTrace = await store.appendWithStageTrace(
                builtEvent,
                pipelineRunID: pipelineRunID,
                now: traceNow
            )
            stages.append(contentsOf: appendTrace.stages)
            let runStatus = appendTrace.errorDescription == nil ? "succeeded" : "failed"
            lastErrorDescription = appendTrace.errorDescription
            let identityResolutionRecords: [ProvenanceIdentityResolutionRecord]
            if let identityResolution {
                identityResolutionRecords = [
                    identityResolutionRecord(
                        pipelineRunID: pipelineRunID,
                        change: change,
                        identityResolution: identityResolution,
                        event: builtEvent,
                        conflictReason: appendTrace.errorDescription
                    )
                ]
            } else {
                identityResolutionRecords = []
            }
            await writeObservability(
                run: runRecord(
                    pipelineRunID: pipelineRunID,
                    change: change,
                    event: builtEvent,
                    status: runStatus,
                    startedAt: runStartedAt,
                    endedAt: traceNow(),
                    errorSummary: appendTrace.errorDescription
                ),
                stages: stages,
                identityResolutions: identityResolutionRecords
            )
        } catch {
            let errorSummary = WorkProvenanceStore.boundedErrorSummary(error)
            lastErrorDescription = errorSummary
            if stages.isEmpty {
                let failedAt = traceNow()
                stages.append(stageRecord(
                    pipelineRunID: pipelineRunID,
                    stageName: "lifecycle_change_received",
                    status: "failed",
                    startedAt: failedAt,
                    endedAt: failedAt,
                    inputCount: 1,
                    outputCount: 0,
                    errorSummary: errorSummary
                ))
            }
            stages.append(skippedStageRecord(
                pipelineRunID: pipelineRunID,
                stageName: "work_provenance_event_append",
                reason: "skipped after lifecycle event construction failed"
            ))
            stages.append(skippedStageRecord(
                pipelineRunID: pipelineRunID,
                stageName: "work_provenance_projection_update",
                reason: "skipped after lifecycle event construction failed"
            ))
            await writeObservability(
                run: runRecord(
                    pipelineRunID: pipelineRunID,
                    change: change,
                    event: builtWorkProvenanceEvent,
                    status: "failed",
                    startedAt: runStartedAt,
                    endedAt: traceNow(),
                    errorSummary: errorSummary
                ),
                stages: stages,
                identityResolutions: []
            )
        }
    }

    /// Builds the append-only event for a lifecycle change.
    func event(
        for change: AgentSubsessionLifecycleChange,
        timestamp: Date
    ) async throws -> WorkProvenanceEvent {
        let identity = lifecycleIdentity(for: change)
        return try await event(for: change, timestamp: timestamp, identity: identity)
    }

    private func event(
        for change: AgentSubsessionLifecycleChange,
        timestamp: Date,
        identity: LifecycleIdentity
    ) async throws -> WorkProvenanceEvent {
        let childSessionID = stableIDFactory.subsessionSessionID(
            agentKind: change.agentKind.sourceName,
            parentSessionID: change.parentSessionID,
            identityKind: identity.kind,
            identityValue: identity.value
        )
        let parentRelationship = try await store.parentSession(for: change.parentSessionID)
        let rootSessionID = parentRelationship?.rootSessionID ?? change.parentSessionID
        let depth = (parentRelationship?.depth ?? 0) + 1
        let confidence = identity.confidence
        let status: String
        let eventType: WorkProvenanceEventType
        let startedAt: Date?
        switch change.phase {
        case .started:
            status = "active"
            eventType = .subsessionStarted
            startedAt = timestamp
        case .stopped:
            status = "completed"
            eventType = .subsessionStopped
            startedAt = nil
        }
        let session = WorkProvenanceSessionRecord(
            id: childSessionID,
            agentKind: change.agentKind.sourceName,
            workspaceID: change.workspaceID,
            surfaceID: change.surfaceID,
            cwd: change.workingDirectory,
            status: status,
            startedAt: startedAt,
            updatedAt: timestamp
        )
        let relationship = WorkProvenanceSessionRelationshipRecord(
            sessionID: childSessionID,
            parentSessionID: change.parentSessionID,
            rootSessionID: rootSessionID,
            depth: depth,
            source: .observed,
            confidence: confidence,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let externalIdentity = WorkProvenanceExternalIdentityRecord(
            id: stableIDFactory.externalIdentityID(
                system: change.agentKind.sourceName,
                kind: identity.kind,
                externalID: identity.value
            ),
            sessionID: childSessionID,
            system: change.agentKind.sourceName,
            kind: identity.kind,
            externalID: identity.value,
            source: .observed,
            confidence: confidence,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return WorkProvenanceEvent(
            id: stableIDFactory.subsessionLifecycleEventID(
                phase: change.phase.provenanceEventIDComponent,
                childSessionID: childSessionID,
                timestamp: timestamp
            ),
            eventType: eventType,
            timestamp: timestamp,
            sessionID: childSessionID,
            source: .observed,
            confidence: confidence,
            payload: WorkProvenanceEventPayload(
                session: session,
                sessionRelationship: relationship,
                externalIdentities: [externalIdentity]
            )
        )
    }

    private func lifecycleIdentity(
        for change: AgentSubsessionLifecycleChange
    ) -> LifecycleIdentity {
        let trimmed = change.subsessionID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return (
                kind: "subsession",
                value: trimmed,
                valueCategory: "native_subsession_id",
                candidateCount: 1,
                confidence: .high,
                outcome: "resolved",
                fallbackState: "native",
                unresolvedReason: nil
            )
        }
        return (
            kind: "unresolved_subsession",
            value: "\(change.agentKind.sourceName):\(change.parentSessionID):default",
            valueCategory: "stable_parent_fallback",
            candidateCount: 0,
            confidence: .low,
            outcome: "unresolved",
            fallbackState: "fallback_unresolved",
            unresolvedReason: "missing_native_subsession_identifier"
        )
    }

    private func writeObservability(
        run: ProvenancePipelineRunRecord,
        stages: [ProvenancePipelineStageExecutionRecord],
        identityResolutions: [ProvenanceIdentityResolutionRecord]
    ) async {
        guard let observabilityStore else { return }
        if awaitObservabilityWrites {
            try? await observabilityStore.record(
                run: run,
                stages: stages,
                identityResolutions: identityResolutions
            )
        } else {
            Task {
                try? await observabilityStore.record(
                    run: run,
                    stages: stages,
                    identityResolutions: identityResolutions
                )
            }
        }
    }

    private func runRecord(
        pipelineRunID: String,
        change: AgentSubsessionLifecycleChange,
        event: WorkProvenanceEvent?,
        status: String,
        startedAt: Date,
        endedAt: Date,
        errorSummary: String?
    ) -> ProvenancePipelineRunRecord {
        ProvenancePipelineRunRecord(
            pipelineRunID: pipelineRunID,
            pipelineKind: "lifecycle_ingestion",
            triggerSource: "AgentSubsessionLifecycleChange",
            parentSessionID: change.parentSessionID,
            childSessionID: event?.payload.session?.id,
            lifecycleEventID: event?.id,
            relationshipSessionID: event?.payload.sessionRelationship?.sessionID,
            externalIdentityID: event?.payload.externalIdentities.first?.id,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            inputCount: 1,
            outputCount: status == "succeeded" ? 1 : 0,
            errorCount: errorSummary == nil ? 0 : 1,
            errorSummary: errorSummary,
            implementationVersion: "o2"
        )
    }

    private func identityResolutionRecord(
        pipelineRunID: String,
        change: AgentSubsessionLifecycleChange,
        identityResolution: LifecycleIdentityResolution,
        event: WorkProvenanceEvent,
        conflictReason: String?
    ) -> ProvenanceIdentityResolutionRecord {
        let identity = identityResolution.identity
        return ProvenanceIdentityResolutionRecord(
            identityResolutionID: "\(pipelineRunID):subsession_identity",
            pipelineRunID: pipelineRunID,
            resolverName: "subsession_lifecycle_identity",
            resolverVersion: "o2",
            triggerSource: "AgentSubsessionLifecycleChange",
            inputPhase: change.phase.provenanceEventIDComponent,
            inputAgentKind: change.agentKind.sourceName,
            inputParentSessionID: change.parentSessionID,
            inputSubsessionIDState: identity.candidateCount == 0 ? "missing" : "present",
            inputWorkspacePresent: change.workspaceID != nil,
            inputSurfacePresent: change.surfaceID != nil,
            inputWorkingDirectoryPresent: change.workingDirectory != nil,
            inputDisplayNamePresent: change.displayName != nil,
            inputIdentityKind: identity.kind,
            inputIdentityValueHash: stableIDFactory.id(prefix: "identity-input", value: identity.value),
            selectedIdentityKind: identity.kind,
            selectedIdentityValueCategory: identity.valueCategory,
            candidateCount: identity.candidateCount,
            selectedChildSessionID: event.payload.session?.id,
            selectedLifecycleEventID: event.id,
            selectedRelationshipSessionID: event.payload.sessionRelationship?.sessionID,
            selectedExternalIdentityID: event.payload.externalIdentities.first?.id,
            confidence: identity.confidence.rawValue,
            outcome: identity.outcome,
            fallbackState: identity.fallbackState,
            unresolvedReason: identity.unresolvedReason,
            conflictReason: conflictReason,
            startedAt: identityResolution.startedAt,
            endedAt: identityResolution.endedAt
        )
    }

    private func stageRecord(
        pipelineRunID: String,
        stageName: String,
        status: String,
        startedAt: Date,
        endedAt: Date,
        inputCount: Int,
        outputCount: Int,
        errorSummary: String?
    ) -> ProvenancePipelineStageExecutionRecord {
        ProvenancePipelineStageExecutionRecord(
            pipelineRunID: pipelineRunID,
            stageName: stageName,
            stageVersion: "o1",
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            inputCount: inputCount,
            outputCount: outputCount,
            errorCount: errorSummary == nil ? 0 : 1,
            errorSummary: errorSummary
        )
    }

    private func skippedStageRecord(
        pipelineRunID: String,
        stageName: String,
        reason: String
    ) -> ProvenancePipelineStageExecutionRecord {
        let timestamp = traceNow()
        return stageRecord(
            pipelineRunID: pipelineRunID,
            stageName: stageName,
            status: "failed",
            startedAt: timestamp,
            endedAt: timestamp,
            inputCount: 0,
            outputCount: 0,
            errorSummary: reason
        )
    }
}

private typealias LifecycleIdentity = (
    kind: String,
    value: String,
    valueCategory: String,
    candidateCount: Int,
    confidence: WorkProvenanceConfidence,
    outcome: String,
    fallbackState: String,
    unresolvedReason: String?
)

private typealias LifecycleIdentityResolution = (
    identity: LifecycleIdentity,
    startedAt: Date,
    endedAt: Date
)

private extension AgentSubsessionLifecycleChange.Phase {
    var provenanceEventIDComponent: String {
        switch self {
        case .started:
            return "started"
        case .stopped:
            return "stopped"
        }
    }
}

extension WorkProvenanceStableIDFactory {
    /// Stable session id for a child agent subsession.
    func subsessionSessionID(
        agentKind: String,
        parentSessionID: String,
        identityKind: String,
        identityValue: String
    ) -> String {
        id(
            prefix: "session",
            value: [
                "subsession",
                agentKind,
                parentSessionID,
                identityKind,
                identityValue,
            ].joined(separator: "\n")
        )
    }

    /// Stable external identity id for a session identity link.
    func externalIdentityID(system: String, kind: String, externalID: String) -> String {
        id(
            prefix: "identity",
            value: [
                system,
                kind,
                externalID,
            ].joined(separator: "\n")
        )
    }

    /// Stable event id for one observed lifecycle transition.
    func subsessionLifecycleEventID(
        phase: String,
        childSessionID: String,
        timestamp: Date
    ) -> String {
        id(
            prefix: "event",
            value: [
                "subsession-lifecycle",
                phase,
                childSessionID,
                String(format: "%.6f", timestamp.timeIntervalSince1970),
            ].joined(separator: "\n")
        )
    }
}
