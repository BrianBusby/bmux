import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository: ProvenanceSessionLifecycleRecording {
    func recordSessionLifecycle(
        _ request: ProvenanceSessionLifecycleRequest
    ) async -> ProvenanceSessionLifecycleResponse {
        var builtEvent: ProvenanceEvent?
        do {
            let event = try await sessionLifecycleEvent(for: request)
            builtEvent = event
            try appendEvent(event)
            return ProvenanceSessionLifecycleResponse(
                accepted: true,
                eventID: event.id,
                sessionID: event.payload.session?.id,
                relationshipSessionID: event.payload.sessionRelationship?.sessionID,
                externalIdentityID: event.payload.externalIdentities.first?.id
            )
        } catch {
            return ProvenanceSessionLifecycleResponse(
                accepted: false,
                eventID: builtEvent?.id,
                sessionID: builtEvent?.payload.session?.id,
                relationshipSessionID: builtEvent?.payload.sessionRelationship?.sessionID,
                externalIdentityID: builtEvent?.payload.externalIdentities.first?.id,
                errorDescription: boundedErrorSummary(error)
            )
        }
    }

    func sessionLifecycleEvent(
        for request: ProvenanceSessionLifecycleRequest
    ) async throws -> ProvenanceEvent {
        let identity = try lifecycleIdentity(for: request)
        let sessionID = try lifecycleSessionID(for: request, identity: identity)
        let trimmedParentSessionID = request.parentSessionID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parentSessionID = trimmedParentSessionID?.isEmpty == false ? trimmedParentSessionID : nil
        let parentRelationship = try parentSessionID.flatMap { try parentSession(for: $0) }
        let rootSessionID = parentSessionID.map { parentRelationship?.rootSessionID ?? $0 }
        let depth = parentRelationship.map { $0.depth + 1 } ?? 1
        let existingSession = try session(id: sessionID)
        let status: String
        let eventType: ProvenanceEventType
        let startedAt: Date?
        switch request.phase {
        case .started:
            status = "active"
            eventType = .sessionStarted
            startedAt = request.timestamp
        case .stopped:
            status = "completed"
            eventType = .sessionStopped
            startedAt = existingSession?.startedAt
        }
        let session = ProvenanceSessionRecord(
            id: sessionID,
            agentKind: request.agentKind,
            workspaceID: request.workspaceID,
            surfaceID: request.surfaceID,
            worktreeID: request.worktreeID,
            cwd: request.workingDirectory,
            status: status,
            startedAt: startedAt,
            updatedAt: request.timestamp
        )
        let relationship = parentSessionID.map {
            ProvenanceSessionRelationshipRecord(
                sessionID: sessionID,
                parentSessionID: $0,
                rootSessionID: rootSessionID ?? $0,
                depth: depth,
                source: .observed,
                confidence: identity.confidence,
                createdAt: request.timestamp,
                updatedAt: request.timestamp
            )
        }
        let externalIdentity = ProvenanceExternalIdentityRecord(
            id: stableIDFactory.externalIdentityID(
                system: request.agentKind,
                kind: identity.kind,
                externalID: identity.value
            ),
            sessionID: sessionID,
            system: request.agentKind,
            kind: identity.kind,
            externalID: identity.value,
            source: .observed,
            confidence: identity.confidence,
            createdAt: request.timestamp,
            updatedAt: request.timestamp
        )
        return ProvenanceEvent(
            id: stableIDFactory.sessionLifecycleEventID(
                phase: request.phase.rawValue,
                sessionID: sessionID,
                timestamp: request.timestamp
            ),
            eventType: eventType,
            timestamp: request.timestamp,
            sessionID: sessionID,
            source: .observed,
            confidence: identity.confidence,
            payload: ProvenanceEventPayload(
                session: session,
                sessionRelationship: relationship,
                externalIdentities: [externalIdentity]
            )
        )
    }

    private func lifecycleSessionID(
        for request: ProvenanceSessionLifecycleRequest,
        identity: (kind: String, value: String, confidence: ProvenanceConfidence)
    ) throws -> String {
        let explicitSessionID = request.sessionID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicitSessionID, !explicitSessionID.isEmpty {
            return explicitSessionID
        }
        if let parentSessionID = request.parentSessionID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !parentSessionID.isEmpty {
            return stableIDFactory.subsessionSessionID(
                agentKind: request.agentKind,
                parentSessionID: parentSessionID,
                identityKind: identity.kind,
                identityValue: identity.value
            )
        }
        return stableIDFactory.sessionID(
            agentKind: request.agentKind,
            identityKind: identity.kind,
            identityValue: identity.value
        )
    }

    private func lifecycleIdentity(
        for request: ProvenanceSessionLifecycleRequest
    ) throws -> (
        kind: String,
        value: String,
        confidence: ProvenanceConfidence
    ) {
        let trimmed = request.externalIdentityValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            let identityKind = request.externalIdentityKind?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                kind: identityKind.flatMap { $0.isEmpty ? nil : $0 } ?? "session",
                value: trimmed,
                confidence: .high
            )
        }
        let sessionID = request.sessionID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sessionID, !sessionID.isEmpty {
            return (
                kind: "session",
                value: sessionID,
                confidence: .high
            )
        }
        throw ProvenanceSQLiteError.sqlite(
            message: "session lifecycle requires a session or external identity"
        )
    }
}
