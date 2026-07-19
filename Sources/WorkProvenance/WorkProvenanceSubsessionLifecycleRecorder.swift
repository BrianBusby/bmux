import Foundation

/// Persists observed agent subsession lifecycle changes into WorkProvenance.
actor WorkProvenanceSubsessionLifecycleRecorder {
    private let store: WorkProvenanceStore
    private let stableIDFactory: WorkProvenanceStableIDFactory

    /// Last persistence error, retained for diagnostics.
    private(set) var lastErrorDescription: String?

    /// Creates a lifecycle recorder.
    init(
        store: WorkProvenanceStore,
        stableIDFactory: WorkProvenanceStableIDFactory = WorkProvenanceStableIDFactory()
    ) {
        self.store = store
        self.stableIDFactory = stableIDFactory
    }

    /// Records a lifecycle change, keeping provenance persistence best-effort.
    func record(_ change: AgentSubsessionLifecycleChange, timestamp: Date) async {
        do {
            let event = try await event(for: change, timestamp: timestamp)
            try await store.append(event)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = String(describing: error)
        }
    }

    /// Builds the append-only event for a lifecycle change.
    func event(
        for change: AgentSubsessionLifecycleChange,
        timestamp: Date
    ) async throws -> WorkProvenanceEvent {
        let identity = nativeIdentity(for: change)
        let childSessionID = stableIDFactory.subsessionSessionID(
            agentKind: change.agentKind.sourceName,
            parentSessionID: change.parentSessionID,
            identityKind: identity.kind,
            identityValue: identity.value
        )
        let parentRelationship = try await store.parentSession(for: change.parentSessionID)
        let rootSessionID = parentRelationship?.rootSessionID ?? change.parentSessionID
        let depth = (parentRelationship?.depth ?? 0) + 1
        let confidence = identity.isNative ? WorkProvenanceConfidence.high : .low
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

    private func nativeIdentity(
        for change: AgentSubsessionLifecycleChange
    ) -> (kind: String, value: String, isNative: Bool) {
        let trimmed = change.subsessionID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return ("subsession", trimmed, true)
        }
        return (
            "unresolved_subsession",
            "\(change.agentKind.sourceName):\(change.parentSessionID):default",
            false
        )
    }
}

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
