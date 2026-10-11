import AppKit
import BmuxUpdater
import ObjectiveC.runtime
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite struct ContentViewFileDropOverlayInstallationTests {
    @Test
    func repeatedLayoutsInstallOneFileDropOverlay() async throws {
        _ = NSApplication.shared
        let notificationStore = TerminalNotificationStore.shared
        let root = ContentView(updateViewModel: UpdateStateModel(), windowId: UUID())
            .environmentObject(TabManager())
            .environmentObject(notificationStore)
            .environmentObject(notificationStore.sidebarUnread)
            .environmentObject(SidebarState())
            .environmentObject(SidebarSelectionState())
            .environmentObject(FileExplorerState())
            .environmentObject(BmuxConfigStore())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = MainWindowHostingView(rootView: root)
        defer {
            NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
            // Unmount observers even if AppKit retains the hidden fixture window.
            window.contentView = nil
            window.orderOut(nil)
        }

        window.makeKeyAndOrderFront(nil)
        for _ in 0..<3 {
            window.displayIfNeeded()
            window.contentView?.layoutSubtreeIfNeeded()
            await Task.yield()
        }

        let themeFrame = try #require(window.contentView?.superview)
        let overlays = fileDropOverlays(in: themeFrame)
        #expect(overlays.count == 1, "ContentView should install exactly one file-drop overlay across repeated layouts.")
        let installedOverlay = try #require(overlays.first)
        #expect(
            (objc_getAssociatedObject(window, &fileDropOverlayKey) as? FileDropOverlayView) === installedOverlay,
            "The window-associated file-drop overlay should match the single installed view."
        )
    }

    private func fileDropOverlays(in root: NSView) -> [FileDropOverlayView] {
        let ownOverlay = (root as? FileDropOverlayView).map { [$0] } ?? []
        return ownOverlay + root.subviews.flatMap { fileDropOverlays(in: $0) }
    }
}
