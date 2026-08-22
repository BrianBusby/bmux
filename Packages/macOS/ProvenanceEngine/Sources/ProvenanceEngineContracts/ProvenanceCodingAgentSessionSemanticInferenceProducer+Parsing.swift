import Foundation

extension ProvenanceCodingAgentSessionSemanticInferenceProducer {
    static func milestones(
        from plan: ProvenanceCodingAgentPlanUpdateRecord
    ) -> [ProvenanceCodingAgentMilestone] {
        let normalizedSteps = plan.steps
            .sorted { lhs, rhs in
                if lhs.order == rhs.order { return lhs.id < rhs.id }
                return lhs.order < rhs.order
            }
            .compactMap { step -> (title: String, status: ProvenanceCodingAgentMilestoneStatus)? in
                guard let title = normalizedEvidenceText(step.text) else { return nil }
                return (title, milestoneStatus(from: step.status))
            }

        return normalizedSteps.enumerated().map { index, step in
            ProvenanceCodingAgentMilestone(
                id: milestoneID(prefix: "plan", title: step.title, order: index),
                title: step.title,
                status: step.status,
                order: index
            )
        }
    }

    static func currentMilestoneID(in milestones: [ProvenanceCodingAgentMilestone]) -> String? {
        if let active = milestones.first(where: { $0.status == .active }) {
            return active.id
        }
        if let planned = milestones.first(where: { $0.status == .planned }) {
            return planned.id
        }
        if let unknown = milestones.first(where: { $0.status == .unknown }) {
            return unknown.id
        }
        return milestones.last(where: { $0.status == .completed })?.id
    }

    static func milestoneID(prefix: String, title: String, order: Int) -> String {
        let fingerprint = fnv1a64Hex("\(prefix)|\(order)|\(title)")
        return ["milestone", prefix, String(order), fingerprint]
            .map(sanitizedIDComponent)
            .joined(separator: "-")
    }

    static func milestoneStatus(from status: String) -> ProvenanceCodingAgentMilestoneStatus {
        let normalized = status
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        switch normalized {
        case "pending", "todo", "planned", "not_started":
            return .planned
        case "in_progress", "active", "started":
            return .active
        case "completed", "complete", "done":
            return .completed
        default:
            return .unknown
        }
    }

    static func currentPlanStep(_ plan: ProvenanceCodingAgentPlanUpdateRecord?) -> ProvenanceCodingAgentPlanStepRecord? {
        guard let plan else { return nil }
        let statusPriority = ["in_progress": 0, "pending": 1, "completed": 2]
        return plan.steps.sorted { lhs, rhs in
            let lhsPriority = statusPriority[lhs.status.lowercased()] ?? 3
            let rhsPriority = statusPriority[rhs.status.lowercased()] ?? 3
            if lhsPriority == rhsPriority { return lhs.order < rhs.order }
            return lhsPriority < rhsPriority
        }.first
    }

    static func normalizedEvidenceText(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return collapsed.isEmpty ? nil : collapsed
    }

    static func normalizedStrings(_ values: [String]) -> [String] {
        values.compactMap(normalizedEvidenceText)
    }

    static func components(from attributions: [ProvenanceCodingAgentFileChangeAttributionRecord]) -> [String] {
        normalizedStrings(attributions.flatMap(\.paths))
    }

    static func parseText(_ text: String) -> TextComponents {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let leading = words.first.map(String.init) ?? ""
        let lowercasedLeading = leading.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":,."))
        let recognizedActions: Set<String> = [
            "add", "adding", "audit", "auditing", "build", "building", "change", "changing", "debug", "debugging",
            "fix", "fixing", "implement", "implementing", "inspect", "inspecting", "investigate", "investigating",
            "migrate", "migrating", "plan", "planning", "read", "reading", "refine", "refining", "refactor",
            "refactoring", "test", "testing", "update", "updating", "validate", "validating", "verify", "verifying",
        ]
        let action = recognizedActions.contains(lowercasedLeading) ? lowercasedLeading : nil
        let remainder = words.count > 1 ? String(words[1]) : nil
        let directional = splitDirectionalSubject(remainder ?? trimmed)
        return TextComponents(
            action: action,
            subject: directional.subject,
            target: directional.target,
            purpose: directional.purpose
        )
    }

    static func splitDirectionalSubject(_ text: String) -> (subject: String?, target: String?, purpose: String?) {
        let separators = [" to use ", " into ", " toward ", " for "]
        let lowercased = text.lowercased()
        for separator in separators {
            if let range = lowercased.range(of: separator) {
                let subject = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let tail = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if separator == " for " {
                    return (subject.isEmpty ? nil : subject, nil, tail.isEmpty ? nil : tail)
                }
                return (subject.isEmpty ? nil : subject, tail.isEmpty ? nil : tail, nil)
            }
        }
        let subject = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (subject.isEmpty ? nil : subject, nil, nil)
    }

    static func activityKind(
        from text: String,
        fallback: ProvenanceCodingAgentActivityKind
    ) -> ProvenanceCodingAgentActivityKind {
        let lowercased = text.lowercased()
        if lowercased.contains("debug") || lowercased.contains("failed") || lowercased.contains("failure") {
            return .debugging
        }
        if lowercased.contains("test") || lowercased.contains("validate") || lowercased.contains("verify") || lowercased.contains("check") {
            return .validation
        }
        if lowercased.contains("inspect") || lowercased.contains("investigat") || lowercased.contains("audit") || lowercased.contains("read") {
            return .investigation
        }
        if lowercased.contains("plan") || lowercased.contains("design") {
            return .planning
        }
        if lowercased.contains("implement") || lowercased.contains("add") || lowercased.contains("change") || lowercased.contains("update") || lowercased.contains("refactor") || lowercased.contains("migrate") {
            return .implementation
        }
        return fallback
    }

    static func isValidationCommand(_ command: String) -> Bool {
        command.contains(" test") || command.hasPrefix("test") || command.contains("swift test") || command.contains("project-docs check") || command.contains("project-docs validate") || command.contains("lint") || command.contains("tsc")
    }

    static func isInspectionCommand(_ command: String) -> Bool {
        ["rg", "sed", "ls", "cat", "find", "git status", "git diff", "git log", "grep"].contains { command == $0 || command.hasPrefix("\($0) ") }
    }

    static func turnSort(
        _ lhs: ProvenanceFactualSessionProjectionTurnSnapshot,
        _ rhs: ProvenanceFactualSessionProjectionTurnSnapshot
    ) -> Bool {
        let lhsDate = lhs.turn.startedAt ?? lhs.turn.completedAt ?? lhs.turn.updatedAt
        let rhsDate = rhs.turn.startedAt ?? rhs.turn.completedAt ?? rhs.turn.updatedAt
        if lhsDate == rhsDate { return lhs.turn.id < rhs.turn.id }
        return lhsDate < rhsDate
    }

    static func deduplicated(_ refs: [ProvenanceSemanticEvidenceReference]) -> [ProvenanceSemanticEvidenceReference] {
        var seen = Set<ProvenanceSemanticEvidenceReference>()
        var result: [ProvenanceSemanticEvidenceReference] = []
        for ref in refs where !seen.contains(ref) {
            result.append(ref)
            seen.insert(ref)
        }
        return result
    }

    static var sortedJSONEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
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
