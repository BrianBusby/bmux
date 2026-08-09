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
    @Test func workspaceSelectUsesCanonicalSelectionPath() throws {
        let manager = TabManager()
        let originalWorkspace = try #require(manager.selectedWorkspace)
        let targetWorkspace = manager.addWorkspace(select: false)
        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(nil) }

        let response = try handleV2Request(
            method: "workspace.select",
            params: ["workspace_id": targetWorkspace.id.uuidString]
        )

        #expect(response["ok"] as? Bool == true)
        let result = try #require(response["result"] as? [String: Any])
        #expect(result["workspace_id"] as? String == targetWorkspace.id.uuidString)
        #expect(manager.selectedTabId == targetWorkspace.id)
        #expect(manager.selectedTabId != originalWorkspace.id)
    }

    @Test func workspaceGroupFocusUsesCanonicalSelectionPath() throws {
        let manager = TabManager()
        let originalWorkspace = try #require(manager.selectedWorkspace)
        let childWorkspace = manager.addWorkspace(select: false)
        let groupId = try #require(manager.createWorkspaceGroup(
            name: "Focus Group",
            childWorkspaceIds: [childWorkspace.id],
            selectAnchor: false,
            collapseSidebarSelection: false
        ))
        let group = try #require(manager.workspaceGroups.first(where: { $0.id == groupId }))
        #expect(manager.selectedTabId == originalWorkspace.id)

        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(nil) }

        let response = try handleV2Request(
            method: "workspace.group.focus",
            params: ["group_id": groupId.uuidString]
        )

        #expect(response["ok"] as? Bool == true)
        let result = try #require(response["result"] as? [String: Any])
        #expect(result["anchor_workspace_id"] as? String == group.anchorWorkspaceId.uuidString)
        #expect(manager.selectedTabId == group.anchorWorkspaceId)
    }

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

    @Test func workspaceActionMarkReadAndUnreadUseCanonicalWorkspaceUnreadPath() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)
        let store = TerminalNotificationStore.shared
        store.replaceNotificationsForTesting([])
        let previousAppDelegate = AppDelegate.shared
        let appDelegate = AppDelegate()
        AppDelegate.shared = appDelegate
        appDelegate.notificationStore = store
        TerminalController.shared.setActiveTabManager(manager)
        defer {
            TerminalController.shared.setActiveTabManager(nil)
            AppDelegate.shared = previousAppDelegate
            store.replaceNotificationsForTesting([])
        }

        let unreadResponse = try handleV2Request(
            method: "workspace.action",
            params: [
                "workspace_id": workspace.id.uuidString,
                "action": "mark_unread"
            ]
        )

        #expect(unreadResponse["ok"] as? Bool == true)
        #expect(store.workspaceIsUnread(forTabId: workspace.id))

        let readResponse = try handleV2Request(
            method: "workspace.action",
            params: [
                "workspace_id": workspace.id.uuidString,
                "action": "mark_read"
            ]
        )

        #expect(readResponse["ok"] as? Bool == true)
        #expect(!store.workspaceIsUnread(forTabId: workspace.id))
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
