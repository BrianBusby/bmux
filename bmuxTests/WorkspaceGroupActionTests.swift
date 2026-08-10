import Foundation
import Testing
import BmuxFoundation
import BmuxSettings

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite("Workspace group actions", .serialized)
struct WorkspaceGroupActionTests {
    private func makeTabManager() -> TabManager {
        let suiteName = "bmux.workspace-group-action-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let manager = TabManager(
            autoWelcomeIfNeeded: false,
            settings: UserDefaultsSettingsClient(defaults: defaults),
            closeTabWarningDefaults: defaults
        )
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        return manager
    }

    @Test func actionHelpersRejectMissingGroups() {
        let manager = makeTabManager()
        let missingGroupId = UUID()
        let missingWorkspaceId = UUID()

        #expect(!manager.renameWorkspaceGroupForAction(groupId: missingGroupId, name: "Renamed"))
        #expect(!manager.setWorkspaceGroupCollapsedForAction(groupId: missingGroupId, isCollapsed: true))
        #expect(!manager.toggleWorkspaceGroupCollapsedForAction(groupId: missingGroupId))
        #expect(!manager.setWorkspaceGroupPinnedForAction(groupId: missingGroupId, isPinned: true))
        #expect(!manager.toggleWorkspaceGroupPinnedForAction(groupId: missingGroupId))
        #expect(!manager.setWorkspaceGroupColorForAction(groupId: missingGroupId, hex: "#123456"))

        let iconResult = manager.setWorkspaceGroupIconForAction(groupId: missingGroupId, symbol: "leaf.fill")
        #expect(!iconResult.found)
        #expect(iconResult.storedSymbol == nil)

        #expect(!manager.setWorkspaceGroupAnchorForAction(groupId: missingGroupId, workspaceId: missingWorkspaceId))
        #expect(!manager.moveWorkspaceGroupForAction(groupId: missingGroupId, toIndex: 0))
        #expect(!manager.ungroupWorkspaceGroupForAction(groupId: missingGroupId))
        #expect(manager.deleteWorkspaceGroupForAction(groupId: missingGroupId) == nil)
        #expect(manager.workspaceGroupDeletionConfirmationForAction(groupId: missingGroupId) == nil)

        let addMissing = manager.addWorkspaceToGroupForAction(
            workspaceId: missingWorkspaceId,
            groupId: missingGroupId
        )
        #expect(!addMissing.workspaceExists)
        #expect(!addMissing.groupExists)
        #expect(addMissing.referenceIsMember)
        #expect(!addMissing.joinedGroup)
        #expect(!addMissing.workspaceIsOtherGroupAnchor)
        #expect(manager.createWorkspaceInGroupForAction(groupId: missingGroupId) == nil)
        #expect(!manager.removeWorkspaceFromGroupForAction(workspaceId: missingWorkspaceId))
    }

    @Test func actionHelpersMutateLiveGroups() throws {
        let manager = makeTabManager()
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        manager.addWorkspace(autoWelcomeIfNeeded: false)
        let childId = manager.tabs[1].id
        let existingUngroupedId = manager.tabs[2].id
        let groupId = try #require(manager.createWorkspaceGroup(name: "Group", childWorkspaceIds: [childId]))
        let secondGroupId = try #require(manager.createWorkspaceGroup(name: "Other"))

        #expect(manager.renameWorkspaceGroupForAction(groupId: groupId, name: "Renamed"))
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.name == "Renamed")
        #expect(manager.setWorkspaceGroupCollapsedForAction(groupId: groupId, isCollapsed: true))
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.isCollapsed == true)
        #expect(manager.toggleWorkspaceGroupCollapsedForAction(groupId: groupId))
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.isCollapsed == false)
        #expect(manager.setWorkspaceGroupPinnedForAction(groupId: groupId, isPinned: true))
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.isPinned == true)
        #expect(manager.toggleWorkspaceGroupPinnedForAction(groupId: groupId))
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.isPinned == false)
        #expect(manager.setWorkspaceGroupColorForAction(groupId: groupId, hex: "#123456"))
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.customColor == "#123456")

        let iconResult = manager.setWorkspaceGroupIconForAction(groupId: groupId, symbol: "  leaf.fill  ")
        #expect(iconResult.found)
        #expect(iconResult.storedSymbol == "leaf.fill")
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.iconSymbol == "leaf.fill")
        #expect(manager.setWorkspaceGroupAnchorForAction(groupId: groupId, workspaceId: childId))
        #expect(manager.workspaceGroups.first { $0.id == groupId }?.anchorWorkspaceId == childId)

        let invalidReference = manager.addWorkspaceToGroupForAction(
            workspaceId: existingUngroupedId,
            groupId: groupId,
            referenceWorkspaceId: UUID()
        )
        #expect(invalidReference.workspaceExists)
        #expect(invalidReference.groupExists)
        #expect(!invalidReference.referenceIsMember)
        #expect(!invalidReference.joinedGroup)

        let addResult = manager.addWorkspaceToGroupForAction(
            workspaceId: existingUngroupedId,
            groupId: groupId,
            placement: .end
        )
        #expect(addResult.workspaceExists)
        #expect(addResult.groupExists)
        #expect(addResult.referenceIsMember)
        #expect(addResult.joinedGroup)
        #expect(!addResult.workspaceIsOtherGroupAnchor)
        #expect(manager.tabs.first { $0.id == existingUngroupedId }?.groupId == groupId)
        #expect(manager.removeWorkspaceFromGroupForAction(workspaceId: existingUngroupedId))
        #expect(manager.tabs.first { $0.id == existingUngroupedId }?.groupId == nil)

        let createdInGroup = try #require(manager.createWorkspaceInGroupForAction(
            groupId: groupId,
            placement: .end,
            referenceWorkspaceId: childId,
            select: false
        ))
        #expect(manager.tabs.first { $0.id == createdInGroup.id }?.groupId == groupId)
        #expect(manager.moveWorkspaceGroupForAction(groupId: secondGroupId, toIndex: 0))
        #expect(manager.workspaceGroups.first?.id == secondGroupId)
        #expect(manager.ungroupWorkspaceGroupForAction(groupId: secondGroupId))
        #expect(!manager.workspaceGroups.contains { $0.id == secondGroupId })

        let confirmation = try #require(manager.workspaceGroupDeletionConfirmationForAction(groupId: groupId))
        let closed = manager.deleteWorkspaceGroupForAction(confirmed: confirmation)
        #expect(closed == confirmation.memberCount)
        #expect(!manager.workspaceGroups.contains { $0.id == groupId })
    }
}
