import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func classifyTurnOutcomeCommand(_ command: String) -> ProvenanceTurnOutcomeCommandClassification {
        let lower = command.lowercased()
        let kind: String
        let supported: Bool
        if lower.contains("swift test")
            || lower.contains("xcodebuild test")
            || lower.contains("yarn test")
            || lower.contains("npm test")
            || lower.contains("npm run test")
            || lower.contains("pytest")
            || lower.contains("rspec")
            || lower.contains("vitest")
            || lower.contains("jest") {
            kind = "test"
            supported = true
        } else if lower.contains("swift build")
            || lower.contains("xcodebuild build")
            || lower.contains("yarn build")
            || lower.contains("npm run build")
            || lower.contains("cargo build") {
            kind = "build"
            supported = true
        } else if lower.contains("lint") || lower.contains("standard") {
            kind = "lint"
            supported = true
        } else if lower.contains("tsc")
            || lower.contains("typecheck")
            || lower.contains("types:check")
            || lower.contains("ts:check") {
            kind = "typecheck"
            supported = true
        } else if lower.contains("format")
            || lower.contains("prettier")
            || lower.contains("swiftformat") {
            kind = "formatter"
            supported = true
        } else if lower.contains("migrate") || lower.contains("db:migrate") {
            kind = "migration"
            supported = true
        } else if lower.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("git ") {
            kind = "git_inspection"
            supported = true
        } else {
            kind = "unsupported"
            supported = false
        }
        return ProvenanceTurnOutcomeCommandClassification(
            kind: kind,
            ruleVersion: Self.turnOutcomeCommandRuleVersion,
            supported: supported
        )
    }

    func isValidationClassification(_ kind: String) -> Bool {
        ["test", "build", "lint", "typecheck", "formatter", "migration"].contains(kind)
    }

    func validationResultStatus(status: String, exitCode: Int?) -> String {
        let normalized = status.lowercased()
        if normalized.contains("cancel") {
            return "cancelled"
        }
        if normalized.contains("interrupt") || normalized.contains("incomplete") {
            return "incomplete"
        }
        if let exitCode {
            return exitCode == 0 ? "passed" : "failed"
        }
        if normalized.contains("success") || normalized.contains("succeed") || normalized == "completed" {
            return "passed"
        }
        if normalized.contains("fail") || normalized.contains("error") {
            return "failed"
        }
        return "unknown"
    }

    func normalizedTurnCompletionState(_ status: String) -> String {
        let normalized = status.lowercased()
        if normalized.contains("cancel") { return "cancelled" }
        if normalized.contains("interrupt") { return "interrupted" }
        if normalized.contains("fail") || normalized.contains("error") { return "failed" }
        if normalized.contains("complete")
            || normalized.contains("success")
            || normalized == "done"
            || normalized == "finished" {
            return "completed"
        }
        if normalized.contains("active")
            || normalized.contains("running")
            || normalized.contains("started")
            || normalized.contains("progress") {
            return "incomplete"
        }
        return "unknown"
    }

    func isCompletedPlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "completed"
            || normalized == "complete"
            || normalized == "done"
            || normalized == "succeeded"
            || normalized == "success"
    }

    func isBlockedPlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "blocked" || normalized == "blocker"
    }

    func isActivePlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "in_progress"
            || normalized == "in progress"
            || normalized == "active"
            || normalized == "running"
    }

    func isPendingPlanStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "pending" || normalized == "todo" || normalized == "deferred"
    }

    func isExplicitCompletedActionReport(_ text: String) -> Bool {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.hasPrefix("completed ")
            || lower.hasPrefix("implemented ")
            || lower.hasPrefix("added ")
            || lower.hasPrefix("updated ")
            || lower.hasPrefix("fixed ")
            || lower.hasPrefix("created ")
            || lower.hasPrefix("removed ")
            || lower.hasPrefix("ran ")
    }

    func turnOutcomeTimestampFingerprint(_ date: Date?) -> String {
        guard let date else { return "" }
        return String(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
    }
}
