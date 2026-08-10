import Foundation
import Bonsplit

extension Workspace {
    @discardableResult
    func renameSurfaceTitleForAction(
        surfaceId: UUID,
        title: String
    ) -> CustomTitleApplyOutcome {
        applySurfaceTitleEditForAction(
            surfaceId: surfaceId,
            title: title,
            emptyTitleClears: false
        )
    }

    @discardableResult
    func commitSurfaceTitleEditForAction(
        surfaceId: UUID,
        title: String
    ) -> CustomTitleApplyOutcome {
        applySurfaceTitleEditForAction(
            surfaceId: surfaceId,
            title: title,
            emptyTitleClears: true
        )
    }

    @discardableResult
    func clearSurfaceTitleForAction(surfaceId: UUID) -> CustomTitleApplyOutcome {
        applySurfaceTitleEditForAction(
            surfaceId: surfaceId,
            title: nil,
            emptyTitleClears: true
        )
    }

    @discardableResult
    func setSurfacePinnedForAction(surfaceId: UUID, pinned: Bool) -> Bool {
        guard panels[surfaceId] != nil else { return false }
        setPanelPinned(panelId: surfaceId, pinned: pinned)
        return true
    }

    @discardableResult
    func toggleSurfacePinnedForAction(surfaceId: UUID) -> Bool? {
        guard panels[surfaceId] != nil else { return nil }
        let pinned = !isPanelPinned(surfaceId)
        setPanelPinned(panelId: surfaceId, pinned: pinned)
        return pinned
    }

    func surfaceIsUnreadForAction(surfaceId: UUID) -> Bool? {
        guard panels[surfaceId] != nil else { return nil }
        return manualUnreadPanelIds.contains(surfaceId) ||
            restoredUnreadPanelIds.contains(surfaceId) ||
            hasUnreadNotificationForSurfaceAction(panelId: surfaceId)
    }

    @discardableResult
    func setSurfaceUnreadForAction(surfaceId: UUID, unread: Bool) -> Bool {
        guard panels[surfaceId] != nil else { return false }
        if unread {
            markPanelUnread(surfaceId)
        } else {
            markPanelRead(surfaceId)
        }
        return true
    }

    @discardableResult
    func toggleSurfaceUnreadForAction(surfaceId: UUID) -> Bool? {
        guard let isUnread = surfaceIsUnreadForAction(surfaceId: surfaceId) else { return nil }
        let unread = !isUnread
        setSurfaceUnreadForAction(surfaceId: surfaceId, unread: unread)
        return unread
    }

    @discardableResult
    func toggleSurfaceSplitZoomForAction(surfaceId: UUID) -> Bool {
        guard panels[surfaceId] != nil else { return false }
        return toggleSplitZoom(panelId: surfaceId)
    }

    @discardableResult
    func toggleSurfaceFullWidthTabForAction(surfaceId: UUID) -> Bool? {
        guard panels[surfaceId] != nil,
              let paneId = paneId(forPanelId: surfaceId),
              toggleFullWidthTabMode(panelId: surfaceId) else {
            return nil
        }
        return bonsplitController.isFullWidthTabMode(inPane: paneId)
    }

    @discardableResult
    func applySurfaceTitleEditForAction(
        surfaceId: UUID,
        title: String?,
        emptyTitleClears: Bool
    ) -> CustomTitleApplyOutcome {
        guard let panelId = panelIdForSurfaceTitleAction(surfaceId) else {
            return .rejected(.targetMissing)
        }
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            if emptyTitleClears {
                return applyPanelCustomTitle(panelId: panelId, title: nil, source: .user)
            }
            return .rejected(.emptyTitle)
        }
        return applyPanelCustomTitle(panelId: panelId, title: trimmed, source: .user)
    }

    private func panelIdForSurfaceTitleAction(_ surfaceId: UUID) -> UUID? {
        if panels[surfaceId] != nil {
            return surfaceId
        }
        return panelIdFromSurfaceId(TabID(uuid: surfaceId))
    }
}
