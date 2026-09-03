import Foundation
import ProvenanceEngineContracts

@MainActor
extension WorkProvenanceRuntime {
    /// Reads the PE factual session projection for the latest coding-agent session in one workspace.
    func agentSessionFactualProjection(stableWorkspaceID: UUID) async -> AgentSessionFactualProjectionReadResult {
        guard let workspaceCodingAgentSessionAssociationStore,
              let agentSessionFactualProjectionStore else {
            return .unavailable
        }
        let associationResult = await workspaceCodingAgentSessionAssociationStore.refreshedAssociation(
            stableWorkspaceID: stableWorkspaceID
        )
        guard case let .available(association, associationReadiness) = associationResult else {
            return Self.factualReadinessResult(associationResult)
        }
        if associationReadiness.status == .agentDetectedAwaitingFirstPrompt {
            return .agentDetectedAwaitingFirstPrompt(associationReadiness)
        }
        let projectionResult = await agentSessionFactualProjectionStore.refreshedSnapshot(sessionID: association.sessionID)
        return Self.factualProjectionResult(
            projectionResult,
            association: association,
            readiness: associationReadiness
        )
    }

    /// Reads the first-pass React Smart Session bridge snapshot for the latest coding-agent session.
    func agentSessionSmartSession(stableWorkspaceID: UUID) async -> AgentSessionSmartSessionReadResult {
        guard let workspaceCodingAgentSessionAssociationStore,
              let agentSessionSmartSessionStore else {
            return .unavailable
        }
        let associationResult = await workspaceCodingAgentSessionAssociationStore.refreshedAssociation(
            stableWorkspaceID: stableWorkspaceID
        )
        guard case let .available(association, associationReadiness) = associationResult else {
            return Self.smartSessionReadinessResult(associationResult)
        }
        if associationReadiness.status == .agentDetectedAwaitingFirstPrompt {
            return .agentDetectedAwaitingFirstPrompt(associationReadiness)
        }
        let smartSessionResult = await agentSessionSmartSessionStore.refreshedSnapshot(sessionID: association.sessionID)
        return Self.smartSessionProjectionResult(
            smartSessionResult,
            association: association,
            readiness: associationReadiness
        )
    }

    private static func factualReadinessResult(
        _ associationResult: WorkspaceCodingAgentSessionAssociationReadResult
    ) -> AgentSessionFactualProjectionReadResult {
        switch associationResult {
        case .unavailable:
            return .unavailable
        case .notFound(let readiness):
            return readiness.status.factualResult(readiness: readiness)
        case .failed(let readiness):
            return .projectionFailed(sessionID: readiness.sessionID, readiness)
        case .available:
            return .unavailable
        }
    }

    private static func factualProjectionResult(
        _ projectionResult: AgentSessionFactualProjectionReadResult,
        association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord,
        readiness: ProvenanceWorkspaceCodingAgentSessionReadiness
    ) -> AgentSessionFactualProjectionReadResult {
        switch projectionResult {
        case .available:
            StartupBreadcrumbLog.append("workProvenance.sessionProjection.available", fields: [
                "workspace": association.workspaceID,
                "session": association.sessionID,
                "stage": "available",
                "sourcePath": association.sourcePath,
                "revision": association.latestEventSequence.map(String.init) ?? "unknown"
            ])
            return projectionResult
        case .notFound(_, let reason):
            let pending = Self.readiness(
                association: association,
                base: readiness,
                status: .associationEstablishedProjectionPending,
                stage: "factual_projection",
                reasonCode: reason ?? "factual_projection_pending",
                retryable: true
            )
            return .associationEstablishedProjectionPending(sessionID: association.sessionID, pending)
        case .failed:
            return .projectionFailed(
                sessionID: association.sessionID,
                Self.readiness(
                    association: association,
                    base: readiness,
                    status: .projectionFailed,
                    stage: "factual_projection",
                    reasonCode: "factual_projection_read_failed",
                    retryable: true
                )
            )
        case .missingSession:
            return .promptObservedAssociationPending(Self.readiness(
                association: association,
                base: readiness,
                status: .promptObservedAssociationPending,
                stage: "factual_projection",
                reasonCode: "projection_session_id_missing",
                retryable: true
            ))
        case .unavailable:
            return .unavailable
        case .noSupportedCodingAgentDetected,
             .agentDetectedAwaitingFirstPrompt,
             .promptObservedAssociationPending,
             .associationEstablishedProjectionPending,
             .ingestionFailed,
             .identityReconciliationFailed,
             .projectionFailed,
             .unsupportedOrUnassociatedSession:
            return projectionResult
        }
    }

    private static func smartSessionReadinessResult(
        _ associationResult: WorkspaceCodingAgentSessionAssociationReadResult
    ) -> AgentSessionSmartSessionReadResult {
        switch associationResult {
        case .unavailable:
            return .unavailable
        case .notFound(let readiness):
            return readiness.status.smartSessionResult(readiness: readiness)
        case .failed(let readiness):
            return .projectionFailed(sessionID: readiness.sessionID, readiness)
        case .available:
            return .unavailable
        }
    }

    private static func smartSessionProjectionResult(
        _ smartSessionResult: AgentSessionSmartSessionReadResult,
        association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord,
        readiness: ProvenanceWorkspaceCodingAgentSessionReadiness
    ) -> AgentSessionSmartSessionReadResult {
        switch smartSessionResult {
        case .available:
            return smartSessionResult
        case .notFound(_, let reason):
            let pending = Self.readiness(
                association: association,
                base: readiness,
                status: .associationEstablishedProjectionPending,
                stage: "smart_session_projection",
                reasonCode: reason ?? "smart_session_projection_pending",
                retryable: true
            )
            return .associationEstablishedProjectionPending(sessionID: association.sessionID, pending)
        case .failed:
            return .projectionFailed(
                sessionID: association.sessionID,
                Self.readiness(
                    association: association,
                    base: readiness,
                    status: .projectionFailed,
                    stage: "smart_session_projection",
                    reasonCode: "smart_session_projection_read_failed",
                    retryable: true
                )
            )
        case .missingSession:
            return .promptObservedAssociationPending(Self.readiness(
                association: association,
                base: readiness,
                status: .promptObservedAssociationPending,
                stage: "smart_session_projection",
                reasonCode: "projection_session_id_missing",
                retryable: true
            ))
        case .unavailable:
            return .unavailable
        case .noSupportedCodingAgentDetected,
             .agentDetectedAwaitingFirstPrompt,
             .promptObservedAssociationPending,
             .associationEstablishedProjectionPending,
             .ingestionFailed,
             .identityReconciliationFailed,
             .projectionFailed,
             .unsupportedOrUnassociatedSession:
            return smartSessionResult
        }
    }

    private static func readiness(
        association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord,
        base: ProvenanceWorkspaceCodingAgentSessionReadiness,
        status: ProvenanceWorkspaceCodingAgentSessionReadinessStatus,
        stage: String,
        reasonCode: String?,
        retryable: Bool
    ) -> ProvenanceWorkspaceCodingAgentSessionReadiness {
        ProvenanceWorkspaceCodingAgentSessionReadiness(
            status: status,
            workspaceID: association.workspaceID,
            agentKind: association.agentKind,
            sessionID: association.sessionID,
            rawSessionID: association.rawSessionID,
            canonicalSessionID: association.canonicalSessionID,
            sourcePath: association.sourcePath,
            stage: stage,
            reasonCode: reasonCode,
            retryable: retryable,
            firstObservedAt: association.firstObservedAt,
            promptObservedAt: association.promptObservedAt,
            lastTransitionAt: Date(),
            latestEventID: association.latestEventID ?? base.latestEventID,
            latestEventSequence: association.latestEventSequence ?? base.latestEventSequence
        )
    }
}

private extension ProvenanceWorkspaceCodingAgentSessionReadinessStatus {
    func factualResult(
        readiness: ProvenanceWorkspaceCodingAgentSessionReadiness
    ) -> AgentSessionFactualProjectionReadResult {
        switch self {
        case .noSupportedCodingAgentDetected:
            return .noSupportedCodingAgentDetected(readiness)
        case .agentDetectedAwaitingFirstPrompt:
            return .agentDetectedAwaitingFirstPrompt(readiness)
        case .promptObservedAssociationPending:
            return .promptObservedAssociationPending(readiness)
        case .associationEstablishedProjectionPending:
            return .associationEstablishedProjectionPending(
                sessionID: readiness.sessionID ?? "",
                readiness
            )
        case .ingestionFailed:
            return .ingestionFailed(readiness)
        case .identityReconciliationFailed:
            return .identityReconciliationFailed(readiness)
        case .projectionFailed:
            return .projectionFailed(sessionID: readiness.sessionID, readiness)
        case .unsupportedOrUnassociatedSession:
            return .unsupportedOrUnassociatedSession(readiness)
        case .available:
            return .associationEstablishedProjectionPending(
                sessionID: readiness.sessionID ?? "",
                readiness
            )
        }
    }

    func smartSessionResult(
        readiness: ProvenanceWorkspaceCodingAgentSessionReadiness
    ) -> AgentSessionSmartSessionReadResult {
        switch self {
        case .noSupportedCodingAgentDetected:
            return .noSupportedCodingAgentDetected(readiness)
        case .agentDetectedAwaitingFirstPrompt:
            return .agentDetectedAwaitingFirstPrompt(readiness)
        case .promptObservedAssociationPending:
            return .promptObservedAssociationPending(readiness)
        case .associationEstablishedProjectionPending:
            return .associationEstablishedProjectionPending(
                sessionID: readiness.sessionID ?? "",
                readiness
            )
        case .ingestionFailed:
            return .ingestionFailed(readiness)
        case .identityReconciliationFailed:
            return .identityReconciliationFailed(readiness)
        case .projectionFailed:
            return .projectionFailed(sessionID: readiness.sessionID, readiness)
        case .unsupportedOrUnassociatedSession:
            return .unsupportedOrUnassociatedSession(readiness)
        case .available:
            return .associationEstablishedProjectionPending(
                sessionID: readiness.sessionID ?? "",
                readiness
            )
        }
    }
}
