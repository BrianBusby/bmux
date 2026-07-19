import Foundation

struct CLIProvenanceLifecycleTraceList: Equatable {
    let found: Bool
    let reason: String?
    let runs: [[String: AnyHashable]]
    let stages: [[String: AnyHashable]]

    var payload: [String: Any] {
        [
            "found": found,
            "reason": reason ?? NSNull(),
            "summary": [
                "run_count": runs.count,
                "stage_count": stages.count,
                "failed_run_count": runs.filter { $0["status"] as? String == "failed" }.count
            ],
            "runs": arrayPayload(runs),
            "stages": arrayPayload(stages)
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
