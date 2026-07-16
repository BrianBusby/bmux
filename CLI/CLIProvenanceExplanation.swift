import Foundation

struct CLIProvenanceExplanation: Equatable {
    let requestedPath: String
    let repositoryPath: String
    let relativePath: String
    let found: Bool
    let reason: String?
    let fileStatus: String?
    let attributionSource: String?
    let attributionConfidence: String?
    let updatedAt: TimeInterval?
    let worktree: [String: AnyHashable]
    let repository: [String: AnyHashable]
    let changeSet: [String: AnyHashable]?
    let checkpoint: [String: AnyHashable]?
    let contribution: [String: AnyHashable]?
    let session: [String: AnyHashable]?
    let workItem: [String: AnyHashable]?

    var payload: [String: Any] {
        var result: [String: Any] = [
            "found": found,
            "requested_path": requestedPath,
            "repository_path": repositoryPath,
            "relative_path": relativePath,
            "worktree": dictionaryPayload(worktree),
            "repository": dictionaryPayload(repository)
        ]
        result["reason"] = reason ?? NSNull()
        result["file_status"] = fileStatus ?? NSNull()
        result["attribution_source"] = attributionSource ?? NSNull()
        result["attribution_confidence"] = attributionConfidence ?? NSNull()
        result["updated_at"] = updatedAt ?? NSNull()
        result["change_set"] = optionalDictionaryPayload(changeSet)
        result["checkpoint"] = optionalDictionaryPayload(checkpoint)
        result["contribution"] = optionalDictionaryPayload(contribution)
        result["session"] = optionalDictionaryPayload(session)
        result["work_item"] = optionalDictionaryPayload(workItem)
        return result
    }

    private func optionalDictionaryPayload(_ value: [String: AnyHashable]?) -> Any {
        guard let value else { return NSNull() }
        return dictionaryPayload(value)
    }

    private func dictionaryPayload(_ value: [String: AnyHashable]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { partial, item in
            partial[item.key] = item.value
        }
    }
}
