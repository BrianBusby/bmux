import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite("Workspace group move-to menu state", .serialized)
@MainActor
struct WorkspaceGroupMoveToMenuStateTests {
    @Test func isDisabledWhenThereAreNoGroups() {
        let state = WorkspaceGroupMoveToMenuState(groups: [])

        #expect(state.isDisabled)
        #expect(!state.rendersSubmenu)
    }

    @Test func usesSubmenuWhenGroupsExist() {
        let group = WorkspaceGroupMenuSnapshot.Item(
            id: UUID(),
            name: "Group"
        )
        let state = WorkspaceGroupMoveToMenuState(groups: [group])

        #expect(!state.isDisabled)
        #expect(state.rendersSubmenu)
    }

    @Test func mobileWorkspaceMoveBlankGroupIDUngroupsWorkspace() throws {
        let manager = TabManager()
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        let originalIds = manager.tabs.map(\.id)
        let groupId = try #require(manager.createWorkspaceGroup(name: "G", childWorkspaceIds: [
            originalIds[1],
            originalIds[2],
        ]))
        let movingWorkspaceID = originalIds[1]
        #expect(manager.tabs.first { $0.id == movingWorkspaceID }?.groupId == groupId)

        let previousManager = TerminalController.shared.activeTabManagerForCallerNotification()
        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(previousManager) }

        let result = TerminalController.shared.v2MobileWorkspaceMove(params: [
            "workspace_id": movingWorkspaceID.uuidString,
            "group_id": "   ",
        ])

        guard case .ok = result else {
            return #expect(Bool(false), "blank group_id should be treated as nil, not invalid_params")
        }
        #expect(manager.tabs.first { $0.id == movingWorkspaceID }?.groupId == nil)
    }

    @Test func mobileWorkspaceMoveGroupHeaderPreservesGroupMembership() throws {
        let manager = TabManager()
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        let originalIds = manager.tabs.map(\.id)
        let groupId = try #require(manager.createWorkspaceGroup(name: "G", childWorkspaceIds: [
            originalIds[1],
            originalIds[2],
        ]))
        let group = try #require(manager.workspaceGroups.first { $0.id == groupId })
        let memberIDs = [originalIds[1], originalIds[2]]

        let previousManager = TerminalController.shared.activeTabManagerForCallerNotification()
        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(previousManager) }

        let result = TerminalController.shared.v2MobileWorkspaceMove(params: [
            "workspace_id": group.anchorWorkspaceId.uuidString,
            "move_group": true,
        ])

        guard case .ok = result else {
            return #expect(Bool(false), "group-header move should be accepted")
        }
        #expect(manager.workspaceGroups.contains { $0.id == groupId })
        #expect(manager.tabs.filter { $0.groupId == groupId }.map(\.id) == [
            group.anchorWorkspaceId,
        ] + memberIDs)
        #expect(manager.tabs.suffix(3).map(\.id) == [group.anchorWorkspaceId] + memberIDs)
    }

    @Test func mobileWorkspaceGroupDeleteRejectsGroupContainingEveryWorkspace() throws {
        let manager = TabManager()
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        let originalIds = manager.tabs.map(\.id)
        let groupId = try #require(manager.createWorkspaceGroup(name: "G", childWorkspaceIds: originalIds))

        let previousManager = TerminalController.shared.activeTabManagerForCallerNotification()
        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(previousManager) }

        let result = TerminalController.shared.v2MobileWorkspaceGroupAction(params: [
            "group_id": groupId.uuidString,
            "action": "delete",
        ])

        guard case .err(let code, _, _) = result else {
            return #expect(Bool(false), "delete group should reject when it would leave a holdout workspace")
        }
        #expect(code == "invalid_request")
        #expect(manager.workspaceGroups.contains { $0.id == groupId })
        #expect(manager.tabs.filter { $0.groupId == groupId }.count == originalIds.count + 1)
    }

    @Test func mobileWorkspaceCloseUsesWorkspaceCloseActionPolicy() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)

        let previousManager = TerminalController.shared.activeTabManagerForCallerNotification()
        TerminalController.shared.setActiveTabManager(manager)
        defer { TerminalController.shared.setActiveTabManager(previousManager) }

        let lastWorkspaceResult = TerminalController.shared.v2MobileWorkspaceClose(params: [
            "workspace_id": workspace.id.uuidString,
        ])

        guard case .err(let lastWorkspaceCode, _, _) = lastWorkspaceResult else {
            return #expect(Bool(false), "mobile close should reject the last workspace")
        }
        #expect(lastWorkspaceCode == "protected")
        #expect(manager.tabs.map(\.id) == [workspace.id])

        let second = manager.addWorkspace(autoWelcomeIfNeeded: false)
        #expect(manager.setWorkspacePinnedForAction(tabId: second.id, pinned: true))

        let pinnedResult = TerminalController.shared.v2MobileWorkspaceClose(params: [
            "workspace_id": second.id.uuidString,
        ])

        guard case .err(let pinnedCode, _, _) = pinnedResult else {
            return #expect(Bool(false), "mobile close should reject pinned workspaces")
        }
        #expect(pinnedCode == "protected")
        #expect(manager.tabs.map(\.id) == [second.id, workspace.id])

        #expect(manager.setWorkspacePinnedForAction(tabId: second.id, pinned: false))
        let acceptedResult = TerminalController.shared.v2MobileWorkspaceClose(params: [
            "workspace_id": second.id.uuidString,
        ])

        guard case .ok = acceptedResult else {
            return #expect(Bool(false), "mobile close should accept an unpinned non-last workspace")
        }
        #expect(manager.tabs.map(\.id) == [workspace.id])
    }
}
