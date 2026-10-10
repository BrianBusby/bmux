import BmuxTerminal
import BmuxTerminalCore
import Foundation

extension GhosttyApp {
    /// Return false for held commands so Ghostty renders its existing exit message instead of losing the output.
    @MainActor
    func handleChildExited(tabId: UUID?, surfaceId: UUID?, surface: TerminalSurface?) -> Bool {
        guard let surfaceId, let surface,
              Self.terminalSurfaceRegistry.surface(id: surfaceId) === surface else { return true }
#if DEBUG
        bmuxDebugLog("surface.action.showChildExited tab=\(tabId?.uuidString.prefix(5) ?? "nil") surface=\(surfaceId.uuidString.prefix(5))")
        TerminalChildExitProbe().write(
            ["probeShowChildExitedTabId": tabId?.uuidString ?? "",
             "probeShowChildExitedSurfaceId": surfaceId.uuidString],
            increments: ["probeShowChildExitedCount": 1])
#endif
        let manager = tabId.flatMap { AppDelegate.shared?.tabManagerFor(tabId: $0) } ?? AppDelegate.shared?.tabManager
        let keepsOutput = tabId.map {
            manager?.shouldKeepLocalCommandOpenAfterChildExit(tabId: $0, surfaceId: surfaceId) == true
        } ?? false
        // Never tear down the runtime surface while Ghostty is dispatching its callback.
        Task { @MainActor [weak surface] in
            guard let surface, Self.terminalSurfaceRegistry.surface(id: surfaceId) === surface,
                  let app = AppDelegate.shared else { return }
            if app.closeWindowDockRuntimeSurface(surfaceId: surfaceId, force: true) { return }
            if let tabId, let manager = app.tabManagerFor(tabId: tabId) ?? app.tabManager {
                manager.closePanelAfterChildExited(tabId: tabId, surfaceId: surfaceId)
            }
        }
        return !keepsOutput
    }
}
