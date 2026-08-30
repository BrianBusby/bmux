import Foundation

extension ProvenanceSemanticMessageRenderer {
    struct RenderedMessage: Equatable {
        let concisePhrase: String
        let expandedMeaning: String
    }

    static func render(_ inference: ProvenanceSemanticInferenceRecord) -> RenderedMessage? {
        guard let kind = ProvenanceCodingAgentSemanticInferenceKind(rawValue: inference.kind) else { return nil }
        switch kind {
        case .threadIntent:
            guard let payload = ProvenanceCodingAgentIntentPayload(semanticPayloadValue: inference.payload) else {
                return nil
            }
            return intentMessage(payload, scopeLabel: "thread")
        case .turnIntent:
            guard let payload = ProvenanceCodingAgentIntentPayload(semanticPayloadValue: inference.payload) else {
                return nil
            }
            return intentMessage(payload, scopeLabel: "turn")
        case .sessionPhase:
            guard let payload = ProvenanceCodingAgentSessionPhasePayload(semanticPayloadValue: inference.payload) else {
                return nil
            }
            return phaseMessage(payload)
        case .milestones:
            guard let payload = ProvenanceCodingAgentMilestonePayload(semanticPayloadValue: inference.payload) else {
                return nil
            }
            return milestonesMessage(payload)
        case .blockers:
            guard let payload = ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: inference.payload) else {
                return nil
            }
            return blockersMessage(payload)
        case .approachChanges:
            guard let payload = ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: inference.payload) else {
                return nil
            }
            return approachChangesMessage(payload)
        case .currentActivity:
            guard let payload = ProvenanceCodingAgentCurrentActivityPayload(semanticPayloadValue: inference.payload) else {
                return nil
            }
            return currentActivityMessage(payload)
        }
    }

    static func intentMessage(_ payload: ProvenanceCodingAgentIntentPayload, scopeLabel: String) -> RenderedMessage {
        if let unknownReason = payload.unknownReason {
            let label = scopeLabel == "thread" ? "Thread intent unknown" : "Turn intent unknown"
            return RenderedMessage(
                concisePhrase: label,
                expandedMeaning: unknownReason
            )
        }
        let phrase = directionalPhrase(
            fallback: payload.summary,
            action: payload.action,
            subject: payload.subject,
            target: payload.target,
            purpose: payload.purpose,
            components: payload.components
        )
        let expanded = "This \(scopeLabel) is trying to \(lowercaseFirst(payload.summary))."
        return RenderedMessage(concisePhrase: phrase, expandedMeaning: expanded)
    }

    static func phaseMessage(_ payload: ProvenanceCodingAgentSessionPhasePayload) -> RenderedMessage {
        if payload.phase == .unknown {
            return RenderedMessage(
                concisePhrase: "Session phase unknown",
                expandedMeaning: payload.reason
            )
        }
        let label = payload.phase.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return RenderedMessage(
            concisePhrase: label,
            expandedMeaning: "The session is in the \(payload.phase.rawValue.replacingOccurrences(of: "_", with: " ")) phase because \(lowercaseFirst(payload.reason))."
        )
    }

    static func milestonesMessage(_ payload: ProvenanceCodingAgentMilestonePayload) -> RenderedMessage {
        if let unknownReason = payload.unknownReason {
            return RenderedMessage(
                concisePhrase: "Milestones unknown",
                expandedMeaning: unknownReason
            )
        }

        guard let currentMilestoneID = payload.currentMilestoneID,
              let currentMilestone = payload.milestones.first(where: { $0.id == currentMilestoneID }) else {
            return RenderedMessage(
                concisePhrase: "Milestones inferred",
                expandedMeaning: "The session has \(payload.milestones.count) inferred milestones."
            )
        }

        return RenderedMessage(
            concisePhrase: currentMilestone.title,
            expandedMeaning: "The current milestone is \(lowercaseFirst(currentMilestone.title))."
        )
    }

    static func blockersMessage(_ payload: ProvenanceCodingAgentBlockerPayload) -> RenderedMessage {
        if let unknownReason = payload.unknownReason {
            return RenderedMessage(
                concisePhrase: "Blockers unknown",
                expandedMeaning: unknownReason
            )
        }

        guard let blocker = payload.blockers.first else {
            return RenderedMessage(
                concisePhrase: "No supported blockers",
                expandedMeaning: "No supported explicit blocker statement is active in the bounded session evidence."
            )
        }

        switch blocker.state {
        case .reportedOpen:
            return RenderedMessage(
                concisePhrase: "Blocked: \(blocker.affectedActivity)",
                expandedMeaning: "The provider reported \(lowercaseFirst(blocker.affectedActivity)) is blocked by \(blocker.condition)."
            )
        case .reportedCleared:
            return RenderedMessage(
                concisePhrase: "Blocker cleared",
                expandedMeaning: "The provider reported the blocker for \(lowercaseFirst(blocker.affectedActivity)) was cleared."
            )
        case .reportedBypassed:
            return RenderedMessage(
                concisePhrase: "Blocker bypassed",
                expandedMeaning: "The provider reported work can proceed by bypassing \(blocker.condition)."
            )
        case .reportedNoLongerApplies:
            return RenderedMessage(
                concisePhrase: "Blocker no longer applies",
                expandedMeaning: "The provider reported \(blocker.condition) no longer applies to \(lowercaseFirst(blocker.affectedActivity))."
            )
        case .unknown:
            return RenderedMessage(
                concisePhrase: "Blocker state unknown",
                expandedMeaning: blocker.description
            )
        }
    }

    static func approachChangesMessage(_ payload: ProvenanceCodingAgentApproachChangePayload) -> RenderedMessage {
        if let unknownReason = payload.unknownReason {
            return RenderedMessage(
                concisePhrase: "Approach changes unknown",
                expandedMeaning: unknownReason
            )
        }

        guard let change = payload.approachChanges.first else {
            return RenderedMessage(
                concisePhrase: "No supported approach changes",
                expandedMeaning: "No supported explicit approach-change statement is active in the bounded session evidence."
            )
        }

        switch change.state {
        case .reportedReplaced:
            return RenderedMessage(
                concisePhrase: "Approach replaced",
                expandedMeaning: "The provider reported replacing \(lowercaseFirst(change.priorApproach)) with \(change.replacementApproach ?? "an unspecified replacement")."
            )
        case .reportedAbandoned:
            return RenderedMessage(
                concisePhrase: "Approach abandoned",
                expandedMeaning: "The provider reported abandoning \(lowercaseFirst(change.priorApproach))."
            )
        case .reportedDeferred:
            return RenderedMessage(
                concisePhrase: "Approach deferred",
                expandedMeaning: "The provider reported deferring \(lowercaseFirst(change.priorApproach))."
            )
        case .reportedFailed:
            return RenderedMessage(
                concisePhrase: "Approach failed",
                expandedMeaning: "The provider reported \(lowercaseFirst(change.priorApproach)) failed."
            )
        case .unknown:
            return RenderedMessage(
                concisePhrase: "Approach-change state unknown",
                expandedMeaning: change.objective
            )
        }
    }

    static func currentActivityMessage(_ payload: ProvenanceCodingAgentCurrentActivityPayload) -> RenderedMessage {
        if let unknownReason = payload.unknownReason, payload.activityKind == .unknown {
            return RenderedMessage(
                concisePhrase: "Current activity unknown",
                expandedMeaning: unknownReason
            )
        }

        switch payload.activityKind {
        case .implementation:
            let displaySubject = payload.subject ?? componentName(from: payload.components)
            let phrase = directionalPhrase(
                fallback: payload.summary,
                action: payload.action,
                subject: payload.subject,
                target: payload.target,
                purpose: payload.purpose,
                components: payload.components
            )
            if let displaySubject, let target = payload.target {
                return RenderedMessage(
                    concisePhrase: phrase,
                    expandedMeaning: "The \(displaySubject) is being changed so it uses \(target)."
                )
            }
            if let displaySubject {
                return RenderedMessage(
                    concisePhrase: phrase,
                    expandedMeaning: "The agent is changing \(lowercaseFirst(displaySubject))."
                )
            }
            return RenderedMessage(
                concisePhrase: phrase,
                expandedMeaning: "The agent is changing \(lowercaseFirst(payload.summary))."
            )
        case .investigation:
            return RenderedMessage(
                concisePhrase: payload.summary,
                expandedMeaning: "The agent is investigating \(lowercaseFirst(payload.subject ?? payload.summary))."
            )
        case .validation:
            let command = payload.summary.removingPrefix("Validating with ")
            return RenderedMessage(
                concisePhrase: payload.summary,
                expandedMeaning: "The agent is validating the current changes using \(command)."
            )
        case .debugging:
            let subject = payload.summary.removingPrefix("Investigating failed command: ")
            return RenderedMessage(
                concisePhrase: payload.summary,
                expandedMeaning: "The agent is investigating the failed command \(subject)."
            )
        case .planning:
            return RenderedMessage(
                concisePhrase: payload.summary,
                expandedMeaning: "The agent is planning \(lowercaseFirst(payload.subject ?? payload.summary))."
            )
        case .waiting:
            return RenderedMessage(
                concisePhrase: payload.summary,
                expandedMeaning: "The agent is waiting because \(lowercaseFirst(payload.summary))."
            )
        case .concluding:
            return RenderedMessage(
                concisePhrase: payload.summary,
                expandedMeaning: "The agent is concluding this work: \(payload.summary)."
            )
        case .unknown:
            return RenderedMessage(
                concisePhrase: "Current activity unknown",
                expandedMeaning: payload.unknownReason ?? payload.summary
            )
        }
    }

    static func directionalPhrase(
        fallback: String,
        action: String?,
        subject: String?,
        target: String?,
        purpose: String?,
        components: [String]
    ) -> String {
        let displaySubject = subject ?? componentName(from: components)
        guard let displaySubject else { return fallback }
        if let target, isChangeAction(action) {
            return "Changing \(displaySubject) to use \(target)"
        }
        if let purpose, isChangeAction(action) {
            return "Changing \(displaySubject) for \(purpose)"
        }
        if let action {
            return "\(canonicalVerb(action)) \(displaySubject)"
        }
        return fallback
    }

    static func isChangeAction(_ action: String?) -> Bool {
        guard let action else { return false }
        return ["add", "adding", "change", "changing", "implement", "implementing", "migrate", "migrating", "refactor", "refactoring", "update", "updating"].contains(action.lowercased())
    }

    static func canonicalVerb(_ action: String) -> String {
        switch action.lowercased() {
        case "add", "adding": return "Adding"
        case "change", "changing": return "Changing"
        case "debug", "debugging": return "Debugging"
        case "implement", "implementing": return "Implementing"
        case "inspect", "inspecting": return "Inspecting"
        case "investigate", "investigating": return "Investigating"
        case "migrate", "migrating": return "Changing"
        case "refactor", "refactoring": return "Refactoring"
        case "test", "testing": return "Testing"
        case "update", "updating": return "Updating"
        case "validate", "validating": return "Validating"
        case "verify", "verifying": return "Verifying"
        default: return action.prefix(1).uppercased() + action.dropFirst()
        }
    }

    static func componentName(from components: [String]) -> String? {
        let selected = components.first { component in
            let lowercased = component.lowercased()
            return !lowercased.contains("test") && !lowercased.contains("/docs/")
        } ?? components.first
        guard let selected else { return nil }
        let lastPathComponent = selected.split(separator: "/").last.map(String.init) ?? selected
        let withoutExtension = lastPathComponent.split(separator: ".").first.map(String.init) ?? lastPathComponent
        return withoutExtension.isEmpty ? nil : withoutExtension
    }

    static func stableMessageID(
        inferenceID: String,
        policy: ProvenanceSemanticMessagePresentationPolicy,
        producerID: String,
        producerVersion: String,
        concisePhrase: String,
        expandedMeaning: String
    ) -> String {
        let fingerprint = fnv1a64Hex("\(inferenceID)|\(policy.id)|\(policy.version)|\(producerID)|\(producerVersion)|\(concisePhrase)|\(expandedMeaning)")
        return ["semantic-message", inferenceID, policy.id, policy.version, fingerprint]
            .map(sanitizedIDComponent)
            .joined(separator: "-")
    }

    static func lowercaseFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    static func fnv1a64Hex(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    static func sanitizedIDComponent(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
            .lowercased()
        return collapsed.isEmpty ? "unknown" : collapsed
    }
}


private extension String {
    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
