import Foundation
import ProvenanceEngineContracts

struct RelatedSessionProfile {
    let session: ProvenanceSessionRecord
    let outcome: ProvenanceSessionOutcome?
    let workModel: ProvenanceSessionWorkModel?
    let externalIdentities: [ProvenanceExternalIdentityRecord]
    let providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity]
    let repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary]
    let worktreeBoundaries: [ProvenanceRelatedSessionWorktreeBoundary]
    let semanticFields: [ProvenanceSessionWorkModelSemanticField]
    let repositoryKeys: Set<String>
    let worktreeKeys: Set<String>
    let branchKeys: Set<String>
    let providerThreadKeys: Set<String>
    let externalIdentityKeys: Set<String>
    let artifactKeys: Set<String>
    let repositoryEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]]
    let worktreeEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]]
    let branchEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]]
    let providerThreadEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]]
    let externalIdentityEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]]
    let artifactEvidence: [String: [ProvenanceRelatedSessionEvidenceReference]]
    let observedAt: [String: Date]
    let sourceEvidence: [ProvenanceRelatedSessionEvidenceReference]
    let freshnessDate: Date
}

struct RelatedSessionTreeContext {
    let ancestors: [String: RelatedSessionTreePath]
    let descendants: [String: RelatedSessionTreePath]
    let siblings: [String: RelatedSessionTreePath]
}

struct RelatedSessionTreePath {
    let depth: Int
    let relationships: [ProvenanceSessionRelationshipRecord]
}

struct RelatedSessionCandidateBrief {
    let brief: ProvenanceRelatedSessionBrief
    let relationshipStrength: Int
    let freshnessDate: Date
}
