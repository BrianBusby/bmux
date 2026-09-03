import Foundation
import ProvenanceEngineContracts

/// Reads PE-owned workspace-to-coding-agent-session associations for Session surfaces.
@MainActor
final class WorkspaceCodingAgentSessionAssociationStore {
    private let client: any ProvenanceEngineClient
    private var associationsByWorkspaceID: [String: ProvenanceWorkspaceCodingAgentSessionAssociationRecord] = [:]
    private var readinessByWorkspaceID: [String: ProvenanceWorkspaceCodingAgentSessionReadiness] = [:]

    init(client: any ProvenanceEngineClient) {
        self.client = client
    }

    func refreshedAssociation(
        stableWorkspaceID: UUID,
        agentKind: String = "codex"
    ) async -> WorkspaceCodingAgentSessionAssociationReadResult {
        let workspaceID = stableWorkspaceID.uuidString
        do {
            let response = try await client.workspaceCodingAgentSessionAssociation(
                ProvenanceWorkspaceCodingAgentSessionAssociationRequest(
                    workspaceID: workspaceID,
                    agentKind: agentKind
                )
            )
            readinessByWorkspaceID[workspaceID] = response.readiness
            guard response.found, let association = response.association else {
                return .notFound(response.readiness)
            }
            associationsByWorkspaceID[workspaceID] = association
            return .available(association, response.readiness)
        } catch {
            StartupBreadcrumbLog.append("workProvenance.workspaceCodingAgentSessionAssociation.refreshFailed", fields: [
                "workspace": workspaceID,
                "agentKind": agentKind,
                "error": String(describing: error)
            ])
            if let association = associationsByWorkspaceID[workspaceID] {
                let readiness = readinessByWorkspaceID[workspaceID] ?? Self.readiness(
                    status: .available,
                    stableWorkspaceID: stableWorkspaceID,
                    agentKind: agentKind,
                    association: association,
                    reasonCode: "last_known_good_after_read_failure",
                    retryable: true
                )
                return .available(association, readiness)
            }
            return .failed(Self.readiness(
                status: .projectionFailed,
                stableWorkspaceID: stableWorkspaceID,
                agentKind: agentKind,
                association: nil,
                stage: "association_read",
                reasonCode: "association_read_failed",
                retryable: true
            ))
        }
    }

    private static func readiness(
        status: ProvenanceWorkspaceCodingAgentSessionReadinessStatus,
        stableWorkspaceID: UUID,
        agentKind: String,
        association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord?,
        stage: String? = nil,
        reasonCode: String?,
        retryable: Bool
    ) -> ProvenanceWorkspaceCodingAgentSessionReadiness {
        ProvenanceWorkspaceCodingAgentSessionReadiness(
            status: status,
            workspaceID: stableWorkspaceID.uuidString,
            agentKind: agentKind,
            sessionID: association?.sessionID,
            rawSessionID: association?.rawSessionID,
            canonicalSessionID: association?.canonicalSessionID,
            sourcePath: association?.sourcePath,
            stage: stage ?? association?.stage ?? "association_read",
            reasonCode: reasonCode,
            retryable: retryable,
            firstObservedAt: association?.firstObservedAt,
            promptObservedAt: association?.promptObservedAt,
            lastTransitionAt: association?.lastTransitionAt,
            latestEventID: association?.latestEventID,
            latestEventSequence: association?.latestEventSequence
        )
    }
}

enum WorkspaceCodingAgentSessionAssociationReadResult: Equatable, Sendable {
    case unavailable
    case notFound(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case failed(ProvenanceWorkspaceCodingAgentSessionReadiness)
    case available(
        ProvenanceWorkspaceCodingAgentSessionAssociationRecord,
        ProvenanceWorkspaceCodingAgentSessionReadiness
    )
}
