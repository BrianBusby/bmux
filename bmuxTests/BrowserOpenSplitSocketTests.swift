import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct BrowserOpenSplitSocketTests {
    @Test func reportsCanonicalPlacementStrategy() throws {
        let defaults = UserDefaults.standard
        let previousBrowserDisabled = defaults.object(forKey: BrowserAvailabilitySettings.disabledKey)
        BrowserAvailabilitySettings.setDisabled(false)
        defer {
            if let previousBrowserDisabled {
                defaults.set(previousBrowserDisabled, forKey: BrowserAvailabilitySettings.disabledKey)
            } else {
                defaults.removeObject(forKey: BrowserAvailabilitySettings.disabledKey)
            }
            TerminalController.shared.setActiveTabManager(nil)
        }

        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let sourceSurfaceId = try #require(workspace.focusedPanelId)
        TerminalController.shared.setActiveTabManager(manager)

        let firstResult = try result(method: "browser.open_split", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": sourceSurfaceId.uuidString,
            "url": "https://example.com",
            "focus": false
        ])
        #expect(firstResult["created_split"] as? Bool == true)
        #expect(firstResult["placement_strategy"] as? String == "split_right")

        let secondResult = try result(method: "browser.open_split", params: [
            "workspace_id": workspace.id.uuidString,
            "surface_id": sourceSurfaceId.uuidString,
            "url": "https://example.test",
            "focus": false
        ])
        #expect(secondResult["created_split"] as? Bool == false)
        #expect(secondResult["placement_strategy"] as? String == "reuse_right_sibling")
    }

    private func result(method: String, params: [String: Any]) throws -> [String: Any] {
        let envelope = try response(method: method, params: params)
        #expect(envelope["ok"] as? Bool == true, "Unexpected JSON-RPC response: \(envelope)")
        return try #require(envelope["result"] as? [String: Any])
    }

    private func response(method: String, params: [String: Any]) throws -> [String: Any] {
        let request = ["jsonrpc": "2.0", "id": 1, "method": method, "params": params] as [String: Any]
        let data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        let line = try #require(String(data: data, encoding: .utf8))
        let raw = TerminalController.shared.handleSocketLine(line)
        let rawData = try #require(raw.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: rawData) as? [String: Any])
    }
}
