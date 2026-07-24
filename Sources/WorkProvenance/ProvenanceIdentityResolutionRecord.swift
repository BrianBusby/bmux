import Foundation

/// Bounded observability record for one lifecycle identity-resolution attempt.
struct ProvenanceIdentityResolutionRecord: Codable, Equatable, Sendable {
    let identityResolutionID: String
    let pipelineRunID: String
    let resolverName: String
    let resolverVersion: String
    let triggerSource: String
    let inputPhase: String
    let inputAgentKind: String
    let inputParentSessionID: String
    let inputSubsessionIDState: String
    let inputWorkspacePresent: Bool
    let inputSurfacePresent: Bool
    let inputWorkingDirectoryPresent: Bool
    let inputDisplayNamePresent: Bool
    let inputIdentityKind: String
    let inputIdentityValueHash: String
    let selectedIdentityKind: String
    let selectedIdentityValueCategory: String
    let candidateCount: Int
    let selectedChildSessionID: String?
    let selectedLifecycleEventID: String?
    let selectedRelationshipSessionID: String?
    let selectedExternalIdentityID: String?
    let confidence: String
    let outcome: String
    let fallbackState: String
    let unresolvedReason: String?
    let conflictReason: String?
    let startedAt: Date
    let endedAt: Date

    var durationMilliseconds: Double {
        max(0, endedAt.timeIntervalSince(startedAt) * 1_000)
    }
}
