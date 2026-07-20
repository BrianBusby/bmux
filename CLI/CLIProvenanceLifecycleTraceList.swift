import Foundation

struct CLIProvenanceLifecycleTraceList: Equatable {
    let found: Bool
    let reason: String?
    let runs: [[String: AnyHashable]]
    let stages: [[String: AnyHashable]]
    let identityResolutions: [[String: AnyHashable]]
    let projectionLineage: [[String: AnyHashable]]

    var payload: [String: Any] {
        let failedRunCount = runs.filter { $0["status"] as? String == "failed" }.count
        let resolvedIdentityResolutionCount = identityResolutions.filter {
            $0["outcome"] as? String == "resolved"
        }.count
        let unresolvedIdentityResolutionCount = identityResolutions.filter {
            $0["outcome"] as? String == "unresolved"
        }.count
        let conflictedIdentityResolutionCount = identityResolutions.filter {
            ($0["conflict_reason"] as? String)?.isEmpty == false
        }.count
        let summary: [String: Any] = [
            "run_count": runs.count,
            "stage_count": stages.count,
            "identity_resolution_count": identityResolutions.count,
            "projection_lineage_count": projectionLineage.count,
            "failed_run_count": failedRunCount,
            "resolved_identity_resolution_count": resolvedIdentityResolutionCount,
            "unresolved_identity_resolution_count": unresolvedIdentityResolutionCount,
            "conflicted_identity_resolution_count": conflictedIdentityResolutionCount
        ]
        return [
            "found": found,
            "reason": reason ?? NSNull(),
            "summary": summary,
            "runs": arrayPayload(runs),
            "stages": arrayPayload(stages),
            "identity_resolutions": arrayPayload(identityResolutions),
            "projection_lineage": arrayPayload(projectionLineage)
        ]
    }

    private func arrayPayload(_ values: [[String: AnyHashable]]) -> [[String: Any]] {
        values.map(dictionaryPayload)
    }

    private func dictionaryPayload(_ value: [String: AnyHashable]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { partial, item in
            partial[item.key] = item.value
        }
    }
}
