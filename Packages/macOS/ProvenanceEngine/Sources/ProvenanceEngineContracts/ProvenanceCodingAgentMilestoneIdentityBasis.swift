import Foundation

/// Evidence basis used to assign a stable coding-agent milestone identity.
public enum ProvenanceCodingAgentMilestoneIdentityBasis: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// The milestone identity is anchored to a provider-supplied plan step identifier.
    case providerPlanStepID = "provider_plan_step_id"

    /// The milestone identity is anchored to unique normalized plan-step text.
    case uniquePlanStepText = "unique_plan_step_text"

    /// The milestone is distinct but its continuity is ambiguous because plan-step text repeats.
    case ambiguousPlanStepText = "ambiguous_plan_step_text"

    /// The milestone identity is anchored to a submitted prompt fallback.
    case submittedPrompt = "submitted_prompt"

    /// The milestone came from an older payload that did not record identity basis.
    case legacyPayload = "legacy_payload"
}
