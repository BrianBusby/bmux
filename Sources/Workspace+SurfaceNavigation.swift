import Foundation
import Bonsplit

extension Workspace {
    enum SurfaceSelectionActionResult: Equatable {
        case selected(surfaceId: UUID, paneId: PaneID)
        case notFound
    }

    /// Select the next surface in the currently focused split pane, or in
    /// workspace Canvas order when Canvas layout is active.
    @discardableResult
    func selectNextSurfaceForAction() -> SurfaceSelectionActionResult {
        if layoutMode == .canvas {
            return selectAdjacentCanvasSurfaceForAction(offset: 1)
        }
        bonsplitController.selectNextTab()
        return applyFocusedPaneSurfaceSelectionForAction()
    }

    /// Select the previous surface in the currently focused split pane, or in
    /// workspace Canvas order when Canvas layout is active.
    @discardableResult
    func selectPreviousSurfaceForAction() -> SurfaceSelectionActionResult {
        if layoutMode == .canvas {
            return selectAdjacentCanvasSurfaceForAction(offset: -1)
        }
        bonsplitController.selectPreviousTab()
        return applyFocusedPaneSurfaceSelectionForAction()
    }

    /// Select a surface by index in the currently focused split pane, or in
    /// workspace Canvas order when Canvas layout is active.
    @discardableResult
    func selectSurfaceForAction(at index: Int) -> SurfaceSelectionActionResult {
        if layoutMode == .canvas {
            return selectCanvasSurfaceForAction(at: index)
        }
        guard let focusedPaneId = bonsplitController.focusedPaneId else { return .notFound }
        let tabs = bonsplitController.tabs(inPane: focusedPaneId)
        guard tabs.indices.contains(index) else { return .notFound }
        bonsplitController.selectTab(tabs[index].id)
        return applyFocusedPaneSurfaceSelectionForAction()
    }

    /// Select the last surface in the currently focused split pane, or in
    /// workspace Canvas order when Canvas layout is active.
    @discardableResult
    func selectLastSurfaceForAction() -> SurfaceSelectionActionResult {
        if layoutMode == .canvas {
            return selectLastCanvasSurfaceForAction()
        }
        guard let focusedPaneId = bonsplitController.focusedPaneId else { return .notFound }
        let tabs = bonsplitController.tabs(inPane: focusedPaneId)
        guard let last = tabs.last else { return .notFound }
        bonsplitController.selectTab(last.id)
        return applyFocusedPaneSurfaceSelectionForAction()
    }

    private func applyFocusedPaneSurfaceSelectionForAction() -> SurfaceSelectionActionResult {
        guard let focusedPaneId = bonsplitController.focusedPaneId else { return .notFound }
        guard let tabId = bonsplitController.selectedTab(inPane: focusedPaneId)?.id else {
            return .notFound
        }
        applyTabSelection(tabId: tabId, inPane: focusedPaneId)
        guard let panelId = panelIdFromSurfaceId(tabId) else { return .notFound }
        return .selected(surfaceId: panelId, paneId: focusedPaneId)
    }

    private func selectAdjacentCanvasSurfaceForAction(offset: Int) -> SurfaceSelectionActionResult {
        guard selectAdjacentCanvasTab(offset: offset),
              let selected = focusedPanelId else {
            return .notFound
        }
        return selectedCanvasSurfaceSelectionResult(panelId: selected)
    }

    private func selectCanvasSurfaceForAction(at index: Int) -> SurfaceSelectionActionResult {
        guard selectCanvasTab(at: index),
              let selected = focusedPanelId else {
            return .notFound
        }
        return selectedCanvasSurfaceSelectionResult(panelId: selected)
    }

    private func selectLastCanvasSurfaceForAction() -> SurfaceSelectionActionResult {
        guard selectLastCanvasTab(),
              let selected = focusedPanelId else {
            return .notFound
        }
        return selectedCanvasSurfaceSelectionResult(panelId: selected)
    }

    private func selectedCanvasSurfaceSelectionResult(panelId: UUID) -> SurfaceSelectionActionResult {
        guard let paneId = bonsplitPaneId(forPanelId: panelId) else { return .notFound }
        return .selected(surfaceId: panelId, paneId: paneId)
    }
}
