import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct WorkspaceActionSocketTests {
    @Test func setDescriptionRejectsWhitespaceOnlyDescription() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        workspace.setCustomDescription("Existing")
        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(nil) }

        let response = try handleV2Request(
            method: "workspace.action",
            params: [
                "workspace_id": workspace.id.uuidString,
                "action": "set_description",
                "description": " \n\t "
            ]
        )

        #expect(response["ok"] as? Bool == false)
        let error = try #require(response["error"] as? [String: Any])
        #expect(error["code"] as? String == "invalid_params")
        #expect(workspace.customDescription == "Existing")
    }

    private func handleV2Request(
        method: String,
        params: [String: Any]
    ) throws -> [String: Any] {
        let requestLine = try makeV2RequestLine(method: method, params: params)
        return try decodeV2Envelope(TerminalController.shared.handleSocketLine(requestLine))
    }

    private func makeV2RequestLine(method: String, params: [String: Any]) throws -> String {
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params
        ]
        let data = try JSONSerialization.data(withJSONObject: request)
        let json = try #require(String(data: data, encoding: .utf8))
        return json
    }

    private func decodeV2Envelope(_ raw: String) throws -> [String: Any] {
        let data = try #require(raw.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
