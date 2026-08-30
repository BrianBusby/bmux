import Foundation

/// Evidence basis used to assign a coding-agent milestone work state.
public enum ProvenanceCodingAgentMilestoneStateBasis: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// The state is normalized from the provider-reported plan-step status.
    case providerPlanStepStatus = "provider_plan_step_status"

    /// The state is an active fallback because a submitted prompt exists without plan evidence.
    case submittedPromptFallback = "submitted_prompt_fallback"

    /// The provider supplied a plan-step status PE cannot safely normalize.
    case unsupportedProviderStatus = "unsupported_provider_status"

    /// No supported state evidence was available.
    case unavailable

    /// The milestone came from an older payload that did not record state basis.
    case legacyPayload = "legacy_payload"
}
