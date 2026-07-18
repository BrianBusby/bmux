import Foundation

struct CodexRolloutParsedWorkItemReference: Equatable, Sendable {
    var kind: ContextEfficiencyWorkItemReferenceKind
    var reference: String
    var repositorySlug: String?
    var number: Int?
    var urlString: String?
    var branchName: String?
    var ticketKey: String?
    var sourceKind: ContextEfficiencyWorkItemReferenceSource
    var confidence: ContextEfficiencyWorkItemReferenceConfidence
    var sourcePath: String
    var sourceReference: ContextEfficiencySourceReference?
    var observedAt: Date?
}
