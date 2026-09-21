import AppKit
import SwiftUI

/// Retains the styled consumer on the terminal panel; it never owns the PTY.
struct TerminalChatWebRenderer: NSViewRepresentable {
    let panel: TerminalPanel
    let reader: any TerminalChatReading
    let appearance: PanelAppearance
    var onStartConnectedSession: (() async throws -> Void)? = nil
    let onTerminal: () -> Void

    func makeCoordinator() -> AgentSessionWebRendererCoordinator { panel.presentation.chatRenderer }

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
        coordinator.onStartConnectedSession = onStartConnectedSession
        coordinator.terminalChatDraft = { [weak reader, weak panel] request in
            guard let runtime = reader as? any TerminalChatConnecting, let panel,
                  let text = request.params["text"] as? String else { throw AgentSessionBridgeError.invalidRequest }
            try runtime.updateConnectedDraft(workspaceID: panel.workspaceId, surfaceID: panel.id,
                sessionID: request.requiredString("sessionId"), text: text)
        }
        coordinator.terminalChatAction = { [weak reader, weak panel] request in
            guard let runtime = reader as? any TerminalChatConnecting, let panel,
                  let requestID = UUID(uuidString: try request.requiredString("requestId")) else {
                throw AgentSessionBridgeError.invalidRequest
            }
            return try await runtime.performConnectedAction(workspaceID: panel.workspaceId, surfaceID: panel.id,
                sessionID: request.requiredString("sessionId"), requestID: requestID,
                text: request.params["text"] as? String ?? "", expectedTurnID: request.params["expectedTurnId"] as? String)
        }
        coordinator.onInteractInTerminal = onTerminal
        coordinator.bind(
            panelId: panel.id, workspaceId: panel.workspaceId, stableWorkspaceId: panel.workspaceId,
            workProvenanceRuntime: nil, rendererKind: .react, initialProviderID: .codex,
            workingDirectory: nil, theme: .resolve(appearance: appearance), isFocused: false
        )
        let webView = coordinator.ensureWebView(onPointerDown: {})
        host.wantsLayer = true
        host.layer?.backgroundColor = appearance.contentBackgroundColor.cgColor
        host.layer?.isOpaque = appearance.contentBackgroundColor.alphaComponent >= 0.999
        webView.underPageBackgroundColor = appearance.contentBackgroundColor
        webView.wantsLayer = true
        webView.layer?.backgroundColor = appearance.contentBackgroundColor.cgColor
        webView.layer?.isOpaque = appearance.contentBackgroundColor.alphaComponent >= 0.999
        let webTheme = AgentSessionWebTheme.resolve(appearance: appearance)
        webView.appearance = NSAppearance(named: webTheme.isDark ? .darkAqua : .aqua)
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
