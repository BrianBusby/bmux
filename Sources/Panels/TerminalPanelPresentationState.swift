import Foundation
import AppKit

@MainActor
final class TerminalPanelPresentationState {
    let chatRenderer = AgentSessionWebRendererCoordinator()
    var onClose: (() -> Void)?

    func close(panel: TerminalPanel) {
        onClose?()
        onClose = nil
        chatRenderer.close()
        // The surface will be cleaned up by its deinit
        // Detach from the window portal on real close so stale hosted views
        // cannot remain above browser panes after split close.
        panel.surface.beginPortalCloseLifecycle(reason: "panel.close")
#if DEBUG
        let frame = String(format: "%.1fx%.1f", panel.hostedView.frame.width, panel.hostedView.frame.height)
        let bounds = String(format: "%.1fx%.1f", panel.hostedView.bounds.width, panel.hostedView.bounds.height)
        bmuxDebugLog(
            "surface.panel.close.begin panel=\(panel.id.uuidString.prefix(5)) " +
            "workspace=\(panel.workspaceId.uuidString.prefix(5)) runtimeSurface=\(panel.surface.surface != nil ? 1 : 0) " +
            "inWindow=\(panel.surface.isViewInWindow ? 1 : 0) hasSuperview=\(panel.hostedView.superview != nil ? 1 : 0) " +
            "hidden=\(panel.hostedView.isHidden ? 1 : 0) frame=\(frame) bounds=\(bounds)"
        )
#endif
        panel.unfocus()
        panel.hostedView.setVisibleInUI(false)
        TerminalWindowPortalRegistry.detach(hostedView: panel.hostedView)
#if DEBUG
        bmuxDebugLog(
            "surface.panel.close.end panel=\(panel.id.uuidString.prefix(5)) " +
            "inWindow=\(panel.surface.isViewInWindow ? 1 : 0) hasSuperview=\(panel.hostedView.superview != nil ? 1 : 0) " +
            "hidden=\(panel.hostedView.isHidden ? 1 : 0)"
        )
#endif
        panel.surface.teardownSurface()
    }
}
