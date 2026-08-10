import Foundation

extension TabManager {
    func workspaceGroupReferenceValidationForAction(
        groupId: UUID,
        referenceWorkspaceId: UUID?
    ) -> (groupExists: Bool, referenceIsMember: Bool) {
        let groupExists = workspaceGroups.contains(where: { $0.id == groupId })
        let referenceIsMember = referenceWorkspaceId.map { referenceId in
            tabs.contains { $0.id == referenceId && $0.groupId == groupId }
        } ?? true
        return (groupExists, referenceIsMember)
    }

    @discardableResult
    func createWorkspaceInGroupForAction(
        groupId: UUID,
        placement explicitPlacement: WorkspaceGroupNewPlacement? = nil,
        referenceWorkspaceId: UUID? = nil,
        select: Bool = true,
        initialSurface: NewWorkspaceInitialSurface = .terminal,
        title: String? = nil,
        initialBrowserURL: URL? = nil,
        initialBrowserOmnibarVisible: Bool = true,
        initialBrowserTransparentBackground: Bool = false
    ) -> Workspace? {
        let validation = workspaceGroupReferenceValidationForAction(
            groupId: groupId,
            referenceWorkspaceId: referenceWorkspaceId
        )
        guard validation.groupExists, validation.referenceIsMember else { return nil }
        return workspaceGrouping.createWorkspaceInGroup(
            groupId: groupId,
            placement: explicitPlacement,
            referenceWorkspaceId: referenceWorkspaceId,
            select: select,
            initialSurface: initialSurface,
            title: title,
            initialBrowserURL: initialBrowserURL,
            initialBrowserOmnibarVisible: initialBrowserOmnibarVisible,
            initialBrowserTransparentBackground: initialBrowserTransparentBackground
        )
    }

    @discardableResult
    func addWorkspaceToGroupForAction(
        workspaceId: UUID,
        groupId: UUID,
        placement: WorkspaceGroupNewPlacement? = nil,
        referenceWorkspaceId: UUID? = nil
    ) -> (
        workspaceExists: Bool,
        groupExists: Bool,
        referenceIsMember: Bool,
        joinedGroup: Bool,
        workspaceIsOtherGroupAnchor: Bool
    ) {
        let workspaceExists = tabs.contains(where: { $0.id == workspaceId })
        let validation = workspaceGroupReferenceValidationForAction(
            groupId: groupId,
            referenceWorkspaceId: referenceWorkspaceId
        )
        guard workspaceExists, validation.groupExists, validation.referenceIsMember else {
            return (
                workspaceExists,
                validation.groupExists,
                validation.referenceIsMember,
                false,
                false
            )
        }
        workspaceGrouping.addWorkspaceToGroup(
            workspaceId: workspaceId,
            groupId: groupId,
            placement: placement,
            referenceWorkspaceId: referenceWorkspaceId
        )
        let joinedGroup = tabs.first(where: { $0.id == workspaceId })?.groupId == groupId
        let workspaceIsOtherGroupAnchor = workspaceGroups.contains {
            $0.id != groupId && $0.anchorWorkspaceId == workspaceId
        }
        return (
            workspaceExists,
            validation.groupExists,
            validation.referenceIsMember,
            joinedGroup,
            workspaceIsOtherGroupAnchor
        )
    }

    @discardableResult
    func removeWorkspaceFromGroupForAction(workspaceId: UUID) -> Bool {
        guard let tab = tabs.first(where: { $0.id == workspaceId }),
              tab.groupId != nil else {
            return false
        }
        workspaceGrouping.removeWorkspaceFromGroup(workspaceId: workspaceId)
        return true
    }

    @discardableResult
    func ungroupWorkspaceGroupForAction(groupId: UUID) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.ungroupWorkspaceGroup(groupId: groupId)
        return true
    }

    func workspaceGroupDeletionConfirmationForAction(
        groupId: UUID,
        fallbackGroupName: String? = nil,
        fallbackAnchorWorkspaceId: UUID? = nil
    ) -> WorkspaceGroupDeletionConfirmation? {
        if let fallbackGroupName, let fallbackAnchorWorkspaceId {
            return workspaceGrouping.deletionConfirmation(
                groupId: groupId,
                fallbackGroupName: fallbackGroupName,
                fallbackAnchorWorkspaceId: fallbackAnchorWorkspaceId
            )
        }
        return workspaceGrouping.deletionConfirmation(groupId: groupId)
    }

    @discardableResult
    func deleteWorkspaceGroupForAction(groupId: UUID, recordHistory: Bool = true) -> Int? {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return nil }
        return workspaceGrouping.deleteWorkspaceGroup(groupId: groupId, recordHistory: recordHistory)
    }

    @discardableResult
    func deleteWorkspaceGroupForAction(
        confirmed confirmation: WorkspaceGroupDeletionConfirmation,
        recordHistory: Bool = true
    ) -> Int {
        workspaceGrouping.deleteWorkspaceGroup(confirmed: confirmation, recordHistory: recordHistory)
    }

    @discardableResult
    func renameWorkspaceGroupForAction(groupId: UUID, name: String) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.renameWorkspaceGroup(groupId: groupId, name: name)
        return true
    }

    @discardableResult
    func toggleWorkspaceGroupCollapsedForAction(groupId: UUID) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.toggleWorkspaceGroupCollapsed(groupId: groupId)
        return true
    }

    @discardableResult
    func setWorkspaceGroupCollapsedForAction(groupId: UUID, isCollapsed: Bool) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.setWorkspaceGroupCollapsed(groupId: groupId, isCollapsed: isCollapsed)
        return true
    }

    @discardableResult
    func toggleWorkspaceGroupPinnedForAction(groupId: UUID) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.toggleWorkspaceGroupPinned(groupId: groupId)
        return true
    }

    @discardableResult
    func setWorkspaceGroupPinnedForAction(groupId: UUID, isPinned: Bool) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.setWorkspaceGroupPinned(groupId: groupId, isPinned: isPinned)
        return true
    }

    @discardableResult
    func setWorkspaceGroupColorForAction(groupId: UUID, hex: String?) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.setWorkspaceGroupColor(groupId: groupId, hex: hex)
        return true
    }

    @discardableResult
    func setWorkspaceGroupIconForAction(groupId: UUID, symbol: String?) -> (found: Bool, storedSymbol: String?) {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else {
            return (false, nil)
        }
        return (true, workspaceGrouping.setWorkspaceGroupIcon(groupId: groupId, symbol: symbol))
    }

    @discardableResult
    func setWorkspaceGroupAnchorForAction(groupId: UUID, workspaceId: UUID) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }),
              tabs.contains(where: { $0.id == workspaceId && $0.groupId == groupId }) else {
            return false
        }
        workspaceGrouping.setWorkspaceGroupAnchor(groupId: groupId, workspaceId: workspaceId)
        return true
    }

    @discardableResult
    func moveWorkspaceGroupForAction(groupId: UUID, toIndex targetIndex: Int) -> Bool {
        guard workspaceGroups.contains(where: { $0.id == groupId }) else { return false }
        workspaceGrouping.moveWorkspaceGroup(groupId: groupId, toIndex: targetIndex)
        return true
    }
}
