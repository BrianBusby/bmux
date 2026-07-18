/// Confidence label for a detected work-item reference.
public enum ContextEfficiencyWorkItemReferenceConfidence: String, Codable, Equatable, Sendable {
    /// The reference appeared explicitly in message, command, or output text.
    case explicitReference = "explicit_reference"
    /// The reference came from compact metadata such as a branch or origin URL.
    case metadata
    /// The reference is a branch-like value that may identify the work item.
    case branchCandidate = "branch_candidate"
}
