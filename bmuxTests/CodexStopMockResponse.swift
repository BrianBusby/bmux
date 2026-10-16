import Foundation

/// Models only the live target and bookkeeping requests made by the Stop hook.
struct CodexStopMockResponse: Sendable {
    let workspaceID: String
    let surfaceID: String

    func response(to line: String) throws -> String? {
        guard line.hasPrefix("{") else { return "OK" }
        let request = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        guard let request, let method = request["method"] as? String else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        // feed.push is also sent as an ID-less JSON-RPC notification.
        if method == "feed.push", request["id"] == nil { return nil }
        guard let id = request["id"] else { throw CocoaError(.propertyListReadCorrupt) }
        let parameters = request["params"] as? [String: Any] ?? [:]
        let result: [String: Any]
        switch method {
        case "surface.list":
            guard parameters["workspace_id"] as? String == workspaceID else {
                return try encoded(["id": id, "ok": false, "error": [
                    "code": "not_found", "message": "Unknown fixture workspace",
                ]])
            }
            result = ["surfaces": [["id": surfaceID, "ref": "surface:1", "index": 1, "focused": true]]]
        case "debug.terminals": result = ["terminals": []]
        case "system.top": result = ["windows": []]
        case "workspace.set_auto_title": result = ["enabled": false]
        case "surface.resume.set", "surface.resume.clear", "feed.push": result = [:]
        default:
            throw NSError(domain: "CodexStopMockResponse", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unexpected mock request: \(line)",
            ])
        }
        return try encoded(["id": id, "ok": true, "result": result])
    }

    private func encoded(_ object: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
}
