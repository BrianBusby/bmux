import AppKit
import SwiftUI

/// Retains the styled consumer on the terminal panel; it never owns the PTY.
struct TerminalChatWebRenderer: NSViewRepresentable {
    let panel: TerminalPanel
    let reader: any TerminalChatReading
    let appearance: PanelAppearance
    let onTerminal: () -> Void

    func makeCoordinator() -> AgentSessionWebRendererCoordinator { panel.chatRenderer }

    func makeNSView(context: Context) -> AgentSessionWebHostView {
        AgentSessionWebHostView()
    }

    func updateNSView(_ host: AgentSessionWebHostView, context: Context) {
        let coordinator = context.coordinator
        coordinator.terminalChatSnapshot = { [weak reader, weak panel] in
            guard let reader, let panel else { return ["status": "unavailable"] }
            return await reader.terminalChatSnapshot(workspaceID: panel.workspaceId, surfaceID: panel.id)
        }
        coordinator.terminalChatRawOutput = { [weak reader, weak panel] sessionID, messageID in
            guard let reader, let panel else { return nil }
            return try await reader.terminalChatRawOutput(
                workspaceID: panel.workspaceId, surfaceID: panel.id, sessionID: sessionID, messageID: messageID
            )
        }
        coordinator.onInteractInTerminal = onTerminal
        coordinator.bind(
            panelId: panel.id, workspaceId: panel.workspaceId, stableWorkspaceId: panel.workspaceId,
            workProvenanceRuntime: nil, rendererKind: .react, initialProviderID: .codex,
            workingDirectory: nil, theme: .resolve(appearance: appearance), isFocused: false
        )
        let webView = coordinator.ensureWebView(onPointerDown: {})
        webView.underPageBackgroundColor = appearance.contentBackgroundColor
        host.attachWebView(webView)
        host.onDidMoveToWindow = { [weak coordinator] in coordinator?.loadShellIfNeeded() }
        host.onGeometryChanged = { [weak coordinator] in coordinator?.flushVisiblePaintIfReady() }
        coordinator.loadShellIfNeeded()
    }

    static func dismantleNSView(_ host: AgentSessionWebHostView, coordinator: AgentSessionWebRendererCoordinator) {
        host.detachHostedWebViewIfOwned(coordinator.webView)
        host.onDidMoveToWindow = nil
        host.onGeometryChanged = nil
    }
}
