import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct BrowserBackgroundPreloadOwnershipTests {
    @Test func initialNavigationConsumesBackgroundPreload() {
        let panel = BrowserPanel(
            workspaceId: UUID(),
            initialURL: URL(string: "about:blank")!,
            preloadInitialNavigationInBackground: true,
            isRemoteWorkspace: false
        )
        defer { panel.close() }

        #expect(panel.hasBackgroundPreloadHost)

        let frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        let realHostWindow = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Swift owns this never-presented window through the complete teardown scope.
        realHostWindow.isReleasedWhenClosed = false
        defer {
            realHostWindow.contentView = nil
            realHostWindow.close()
        }
        let contentView = NSView(frame: frame)
        realHostWindow.contentView = contentView
        panel.webView.removeFromSuperview()
        contentView.addSubview(panel.webView)

        panel.releaseBackgroundPreloadHostIfAttachedToRealWindow(reason: "test.realWindow")

        #expect(!panel.hasBackgroundPreloadHost)

        panel.webView.removeFromSuperview()
        realHostWindow.contentView = nil
        panel.navigate(to: URL(string: "about:blank#second")!)

        #expect(!panel.hasBackgroundPreloadHost)
    }
}
