import Foundation
import ProvenanceEngineContracts

extension AgentSessionSmartSessionSnapshot.SemanticField {
    static func summary(
        kind: String,
        record: ProvenanceSessionWorkModelSemanticRecord?
    ) -> String? {
        guard let record else { return nil }
        switch kind {
        case ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue:
            return ProvenanceCodingAgentIntentPayload(semanticPayloadValue: record.payload)?.summary
        case ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue:
            guard let payload = ProvenanceCodingAgentCurrentActivityPayload(semanticPayloadValue: record.payload) else {
                return nil
            }
            return localizedActivitySummary(payload)
        case ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue:
            guard let payload = ProvenanceCodingAgentSessionPhasePayload(semanticPayloadValue: record.payload) else {
                return nil
            }
            return localizedPhaseLabel(payload.phase)
        default:
            return nil
        }
    }

    static func detail(
        kind: String,
        record: ProvenanceSessionWorkModelSemanticRecord?
    ) -> String? {
        guard let record else { return nil }
        switch kind {
        case ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
            ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue:
            return ProvenanceCodingAgentIntentPayload(semanticPayloadValue: record.payload)?.sourceText
        case ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue:
            guard let payload = ProvenanceCodingAgentCurrentActivityPayload(semanticPayloadValue: record.payload) else {
                return nil
            }
            return localizedActivityBasisDetail(payload.basis)
        case ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue:
            return ProvenanceCodingAgentSessionPhasePayload(semanticPayloadValue: record.payload)?.reason
        default:
            return nil
        }
    }

    private static func localizedPhaseLabel(_ phase: ProvenanceCodingAgentSessionPhase) -> String {
        switch phase {
        case .understanding:
            return String(localized: "agentSession.web.smartSession.phase.understanding", defaultValue: "Understanding")
        case .investigation:
            return String(localized: "agentSession.web.smartSession.phase.investigation", defaultValue: "Investigation")
        case .planning:
            return String(localized: "agentSession.web.smartSession.phase.planning", defaultValue: "Planning")
        case .implementation:
            return String(localized: "agentSession.web.smartSession.phase.implementation", defaultValue: "Implementation")
        case .validation:
            return String(localized: "agentSession.web.smartSession.phase.validation", defaultValue: "Validation")
        case .debugging:
            return String(localized: "agentSession.web.smartSession.phase.debugging", defaultValue: "Debugging")
        case .waitingBlocked:
            return String(localized: "agentSession.web.smartSession.phase.waiting", defaultValue: "Waiting")
        case .concluding:
            return String(localized: "agentSession.web.smartSession.phase.concluding", defaultValue: "Concluding")
        case .unknown:
            return String(localized: "agentSession.web.smartSession.unknown", defaultValue: "Unknown")
        }
    }

    private static func localizedActivityBasisDetail(_ basis: String) -> String {
        switch basis {
        case "missing_turn":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.missingTurn",
                defaultValue: "No current turn evidence"
            )
        case "insufficient_turn_evidence":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.insufficientTurnEvidence",
                defaultValue: "Not enough turn evidence yet"
            )
        case "file_change_attribution":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.fileChangeAttribution",
                defaultValue: "Based on file changes"
            )
        case "current_plan":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.currentPlan",
                defaultValue: "Based on the current plan"
            )
        case "visible_reasoning_summary":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.visibleReasoningSummary",
                defaultValue: "Based on visible reasoning"
            )
        case "submitted_prompt", "coding_agent_prompt":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.submittedPrompt",
                defaultValue: "Based on the submitted prompt"
            )
        case "failed_command":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.failedCommand",
                defaultValue: "Based on a failed command"
            )
        case "completed_command":
            return String(
                localized: "agentSession.web.smartSession.activityBasis.completedCommand",
                defaultValue: "Based on completed commands"
            )
        default:
            return String(
                localized: "agentSession.web.smartSession.activityBasis.semanticEvidence",
                defaultValue: "Based on semantic evidence"
            )
        }
    }

    private static func localizedActivitySummary(_ payload: ProvenanceCodingAgentCurrentActivityPayload) -> String {
        switch (payload.basis, payload.activityKind, payload.summary) {
        case let ("completed_command", .validation, summary) where summary.hasPrefix("Validating with "):
            return String(
                localized: "agentSession.web.smartSession.activitySummary.validatingCurrentChanges",
                defaultValue: "Validating current changes"
            )
        case let ("completed_command", .investigation, summary) where summary.hasPrefix("Inspecting with "):
            return String(
                localized: "agentSession.web.smartSession.activitySummary.inspectingWorkspaceEvidence",
                defaultValue: "Inspecting workspace evidence"
            )
        case let ("failed_command", .debugging, summary) where summary.hasPrefix("Investigating failed command: "):
            return String(
                localized: "agentSession.web.smartSession.activitySummary.investigatingFailedCommand",
                defaultValue: "Investigating failed command"
            )
        default:
            return payload.summary
        }
    }
}
