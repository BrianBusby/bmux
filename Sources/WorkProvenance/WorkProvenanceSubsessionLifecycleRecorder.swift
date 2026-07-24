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
        _ = await recordSubsessionLifecycle(
            ProvenanceSubsessionLifecycleRequest(change: change, timestamp: timestamp),
            triggerSource: "AgentSubsessionLifecycleChange"
        )
    }

    private func recordSubsessionLifecycle(
        _ request: ProvenanceSubsessionLifecycleRequest,
        triggerSource: String
    ) async -> ProvenanceSubsessionLifecycleResponse {
        let pipelineRunID = UUID().uuidString
        let runStartedAt = traceNow()
        var stages: [ProvenancePipelineStageExecutionRecord] = []
        var projectionLineage: [ProvenanceProjectionLineageRecord] = []
        var builtWorkProvenanceEvent: WorkProvenanceEvent?
        var identityResolution: LifecycleIdentityResolution?
        do {
            let receivedStartedAt = traceNow()
            let resolutionStartedAt = traceNow()
            let identity = lifecycleIdentity(for: request)
            let builtEvent = try await event(for: request, identity: identity)
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
            projectionLineage = appendTrace.projectionLineage
            let runStatus = appendTrace.errorDescription == nil ? "succeeded" : "failed"
            lastErrorDescription = appendTrace.errorDescription
            let identityResolutionRecords: [ProvenanceIdentityResolutionRecord]
            if let identityResolution {
                identityResolutionRecords = [
                    identityResolutionRecord(
                        pipelineRunID: pipelineRunID,
                        request: request,
                        triggerSource: triggerSource,
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
                    request: request,
                    triggerSource: triggerSource,
                    event: builtEvent,
                    status: runStatus,
                    startedAt: runStartedAt,
                    endedAt: traceNow(),
                    errorSummary: appendTrace.errorDescription
                ),
                stages: stages,
                identityResolutions: identityResolutionRecords,
                projectionLineage: projectionLineage
            )
            return ProvenanceSubsessionLifecycleResponse(
                accepted: appendTrace.errorDescription == nil,
                eventID: builtEvent.id,
                childSessionID: builtEvent.payload.session?.id,
                relationshipSessionID: builtEvent.payload.sessionRelationship?.sessionID,
                externalIdentityID: builtEvent.payload.externalIdentities.first?.id,
                errorDescription: appendTrace.errorDescription
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
                    request: request,
                    triggerSource: triggerSource,
                    event: builtWorkProvenanceEvent,
                    status: "failed",
                    startedAt: runStartedAt,
                    endedAt: traceNow(),
                    errorSummary: errorSummary
                ),
                stages: stages,
                identityResolutions: [],
                projectionLineage: []
            )
            return ProvenanceSubsessionLifecycleResponse(
                accepted: false,
                eventID: builtWorkProvenanceEvent?.id,
                childSessionID: builtWorkProvenanceEvent?.payload.session?.id,
                relationshipSessionID: builtWorkProvenanceEvent?.payload.sessionRelationship?.sessionID,
                externalIdentityID: builtWorkProvenanceEvent?.payload.externalIdentities.first?.id,
                errorDescription: errorSummary
            )
        }
    }

    /// Builds the append-only event for a lifecycle change.
    func event(
        for change: AgentSubsessionLifecycleChange,
        timestamp: Date
    ) async throws -> WorkProvenanceEvent {
        try await subsessionLifecycleEvent(for: ProvenanceSubsessionLifecycleRequest(
            change: change,
            timestamp: timestamp
        ))
    }

    private func event(
        for request: ProvenanceSubsessionLifecycleRequest,
        identity: LifecycleIdentity
    ) async throws -> WorkProvenanceEvent {
        let childSessionID = stableIDFactory.subsessionSessionID(
            agentKind: request.agentKind,
            parentSessionID: request.parentSessionID,
            identityKind: identity.kind,
            identityValue: identity.value
        )
        let parentRelationship = try await store.parentSession(for: request.parentSessionID)
        let rootSessionID = parentRelationship?.rootSessionID ?? request.parentSessionID
        let depth = (parentRelationship?.depth ?? 0) + 1
        let confidence = identity.confidence
        let status: String
        let eventType: WorkProvenanceEventType
        let startedAt: Date?
        switch request.phase {
        case .started:
            status = "active"
            eventType = .subsessionStarted
            startedAt = request.timestamp
        case .stopped:
            status = "completed"
            eventType = .subsessionStopped
            startedAt = nil
        }
        let session = WorkProvenanceSessionRecord(
            id: childSessionID,
            agentKind: request.agentKind,
            workspaceID: request.workspaceID,
            surfaceID: request.surfaceID,
            cwd: request.workingDirectory,
            status: status,
            startedAt: startedAt,
            updatedAt: request.timestamp
        )
        let relationship = WorkProvenanceSessionRelationshipRecord(
            sessionID: childSessionID,
            parentSessionID: request.parentSessionID,
            rootSessionID: rootSessionID,
            depth: depth,
            source: .observed,
            confidence: confidence,
            createdAt: request.timestamp,
            updatedAt: request.timestamp
        )
        let externalIdentity = WorkProvenanceExternalIdentityRecord(
            id: stableIDFactory.externalIdentityID(
                system: request.agentKind,
                kind: identity.kind,
                externalID: identity.value
            ),
            sessionID: childSessionID,
            system: request.agentKind,
            kind: identity.kind,
            externalID: identity.value,
            source: .observed,
            confidence: confidence,
            createdAt: request.timestamp,
            updatedAt: request.timestamp
        )
        return WorkProvenanceEvent(
            id: stableIDFactory.subsessionLifecycleEventID(
                phase: request.phase.rawValue,
                childSessionID: childSessionID,
                timestamp: request.timestamp
            ),
            eventType: eventType,
            timestamp: request.timestamp,
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
        for request: ProvenanceSubsessionLifecycleRequest
    ) -> LifecycleIdentity {
        let trimmed = request.externalIdentityValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            let identityKind = request.externalIdentityKind?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = identityKind.flatMap { $0.isEmpty ? nil : $0 } ?? "subsession"
            return (
                kind: kind,
                value: trimmed,
                valueCategory: kind == "subsession" ? "native_subsession_id" : "external_lifecycle_identity",
                candidateCount: 1,
                confidence: .high,
                outcome: "resolved",
                fallbackState: "native",
                unresolvedReason: nil
            )
        }
        return (
            kind: "unresolved_subsession",
            value: "\(request.agentKind):\(request.parentSessionID):default",
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
        identityResolutions: [ProvenanceIdentityResolutionRecord],
        projectionLineage: [ProvenanceProjectionLineageRecord]
    ) async {
        guard let observabilityStore else { return }
        if awaitObservabilityWrites {
            try? await observabilityStore.record(
                run: run,
                stages: stages,
                identityResolutions: identityResolutions,
                projectionLineage: projectionLineage
            )
        } else {
            Task {
                try? await observabilityStore.record(
                    run: run,
                    stages: stages,
                    identityResolutions: identityResolutions,
                    projectionLineage: projectionLineage
                )
            }
        }
    }

    private func runRecord(
        pipelineRunID: String,
        request: ProvenanceSubsessionLifecycleRequest,
        triggerSource: String,
        event: WorkProvenanceEvent?,
        status: String,
        startedAt: Date,
        endedAt: Date,
        errorSummary: String?
    ) -> ProvenancePipelineRunRecord {
        ProvenancePipelineRunRecord(
            pipelineRunID: pipelineRunID,
            pipelineKind: "lifecycle_ingestion",
            triggerSource: triggerSource,
            parentSessionID: request.parentSessionID,
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
            implementationVersion: "o3"
        )
    }

    private func identityResolutionRecord(
        pipelineRunID: String,
        request: ProvenanceSubsessionLifecycleRequest,
        triggerSource: String,
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
            triggerSource: triggerSource,
            inputPhase: request.phase.rawValue,
            inputAgentKind: request.agentKind,
            inputParentSessionID: request.parentSessionID,
            inputSubsessionIDState: identity.candidateCount == 0 ? "missing" : "present",
            inputWorkspacePresent: request.workspaceID != nil,
            inputSurfacePresent: request.surfaceID != nil,
            inputWorkingDirectoryPresent: request.workingDirectory != nil,
            inputDisplayNamePresent: request.displayName != nil,
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

extension WorkProvenanceSubsessionLifecycleRecorder: ProvenanceSubsessionLifecycleRecording {
    func recordSubsessionLifecycle(
        _ request: ProvenanceSubsessionLifecycleRequest
    ) async -> ProvenanceSubsessionLifecycleResponse {
        await recordSubsessionLifecycle(
            request,
            triggerSource: "ProvenanceSubsessionLifecycleRequest"
        )
    }

    func subsessionLifecycleEvent(
        for request: ProvenanceSubsessionLifecycleRequest
    ) async throws -> WorkProvenanceEvent {
        let identity = lifecycleIdentity(for: request)
        return try await event(for: request, identity: identity)
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

private extension ProvenanceSubsessionLifecycleRequest {
    init(change: AgentSubsessionLifecycleChange, timestamp: Date) {
        self.init(
            phase: ProvenanceSubsessionLifecyclePhase(change.phase),
            parentSessionID: change.parentSessionID,
            agentKind: change.agentKind.sourceName,
            workspaceID: change.workspaceID,
            surfaceID: change.surfaceID,
            workingDirectory: change.workingDirectory,
            externalIdentityKind: "subsession",
            externalIdentityValue: change.subsessionID,
            displayName: change.displayName,
            timestamp: timestamp
        )
    }
}

private extension ProvenanceSubsessionLifecyclePhase {
    init(_ phase: AgentSubsessionLifecycleChange.Phase) {
        switch phase {
        case .started:
            self = .started
        case .stopped:
            self = .stopped
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
