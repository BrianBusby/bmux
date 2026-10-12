import AppKit
import BmuxAppKitSupportUI
import BmuxFoundation
import BmuxTerminalCore
import Bonsplit
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Renders both matte ancestors and the real native split-host boundary.
@MainActor
@Suite(.serialized) struct MatteTerminalBackdropCompositionTests {
    @Test(.timeLimit(.minutes(1)), arguments: [false, true], [1.0, 0.5])
    func splitTerminalsRetainConfiguredBackdropAndMatteChrome(isDark: Bool, opacity: Double) async throws {
        try await checkComposition(isDark: isDark, opacity: opacity, blur: .disabled)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func glassBackdropRemainsOwnedByWindow(isDark: Bool) async throws {
        try await checkComposition(isDark: isDark, opacity: 1, blur: .macosGlassClear)
    }

    private func checkComposition(isDark: Bool, opacity: Double, blur: GhosttyBackgroundBlur) async throws {
        let scheme: ColorScheme = isDark ? .dark : .light
        let theme = MatteTheme(colorScheme: scheme)
        var config = GhosttyConfig()
        config.backgroundColor = NSColor(srgbRed: 0.08, green: 0.19, blue: 0.27, alpha: 1)
        config.backgroundOpacity = opacity
        // Isolate backdrop ownership from the separately tested inactive-pane overlay.
        config.unfocusedSplitOpacity = 1
        config.backgroundBlur = blur
        let fixtureConfig = config
        let defaults = try #require(UserDefaults(suiteName: "MatteBackdrop.\(UUID())"))
        let snapshot = WindowAppearanceResolver(terminalAppearance: .init(
            backgroundColor: config.backgroundColor, backgroundOpacity: opacity,
            backgroundBlur: blur, usesHostLayerBackground: true
        )).currentFromUserDefaults(defaults: defaults, colorScheme: scheme)
        let manager = TabManager(autoWelcomeIfNeeded: false)
        let workspace = try #require(manager.selectedWorkspace)
        let first = try #require(workspace.focusedPanelId)
        _ = try #require(workspace.newTerminalSplit(from: first, orientation: .horizontal, focus: false))
        defer { for panel in workspace.panels.values { panel.close() } }
        let sentinel = Color(nsColor: NSColor(srgbRed: 0.75, green: 0.16, blue: 0.48, alpha: 1))
        let root: (Bool) -> AnyView = { isVisible in
            let terminal = WorkspaceContentView(
                workspace: workspace, isWorkspaceVisible: isVisible, isWorkspaceInputActive: isVisible,
                isFullScreen: false, workspacePortalPriority: 0, windowAppearance: snapshot,
                onThemeRefreshRequest: nil, appearanceConfigLoader: { _, _ in fixtureConfig }
            )
            .environmentObject(TerminalNotificationStore.shared)
            .environment(\.bmuxShellTerminalOnly, true)
            return AnyView(ZStack {
                sentinel
                WindowBackdropLayer(role: .windowRoot, snapshot: snapshot)
                WorkspaceReferenceAppShell { Color.clear } content: {
                    AgentSessionFactualProjectionView(
                        result: .missingSession, isLoading: false, backgroundColor: .clear, onRefresh: {},
                        liveTerminalContent: AnyView(terminal), initialPrimaryTab: .terminal,
                        workspaceLabel: "Project", sessionTitle: "Terminal"
                    )
                }
            }
            .environment(\.colorScheme, scheme))
        }
        let host = NSHostingView(rootView: root(true))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1092, height: 593),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // Both the fixture and its oracle use the same window-server color pipeline.
        window.colorSpace = .sRGB
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        let split = try #require(findSplit(in: host))
        split.adjustSubviews()
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        #expect(split.arrangedSubviews.count == 2, "The fixture must cross real NSSplitView child hosting roots")
        try #require(!split.isHidden, "Visible workspaces must render their native split hosts")
        let image = try await capture(window)
        let expectedTerminal = try await renderedColor(ZStack {
            sentinel
            WindowBackdropLayer(role: .windowRoot, snapshot: snapshot)
        })
        let expectedPanel = try await renderedColor(Color(nsColor: theme.color(.panel)))
        let expectedBase = try await renderedColor(Color(nsColor: theme.color(.base)))
        for pane in split.arrangedSubviews {
            let center = pane.convert(NSPoint(x: pane.bounds.midX, y: pane.bounds.midY), to: host)
            try expect(image, at: center, in: host, equals: expectedTerminal, label: "terminal center")
            let top = pane.isFlipped ? pane.bounds.minY + 5 : pane.bounds.maxY - 5
            // Sample empty bar chrome, away from selected-tab fill and glyphs.
            let tabBar = pane.convert(NSPoint(x: pane.bounds.maxX - 5, y: top), to: host)
            try expect(image, at: tabBar, in: host, equals: expectedPanel, label: "opaque tab chrome")
        }
        let splitRect = split.convert(split.bounds, to: host)
        try expect(image, at: NSPoint(x: splitRect.minX - 10, y: splitRect.midY), in: host,
                   equals: expectedPanel, label: "main panel margin")
        try expect(image, at: NSPoint(x: 50, y: host.bounds.midY), in: host,
                   equals: expectedBase, label: "sidebar base")
        if opacity < 1 || blur.isMacOSGlassStyle {
            let centers = split.arrangedSubviews.map {
                $0.convert(NSPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: host)
            }
            for visible in [false, true] {
                host.rootView = root(visible)
                host.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                let updated = try await capture(window)
                for center in centers {
                    try expect(updated, at: center, in: host,
                               equals: visible ? expectedTerminal : expectedPanel,
                               label: visible ? "remounted terminal backdrop" : "hidden workspace has no aperture")
                }
            }
        }
    }

    private func capture(_ window: NSWindow) async throws -> NSBitmapImageRep {
        // Commit the actual layer tree before requesting window-server pixels.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            CATransaction.begin()
            CATransaction.setCompletionBlock { continuation.resume() }
            window.contentView?.layer?.setNeedsDisplay()
            CATransaction.commit()
            CATransaction.flush()
        }
        let data = try #require(TerminalController.shared.captureCompositedWindowPNGData(window))
        return try #require(NSBitmapImageRep(data: data))
    }

    private func findSplit(in view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView { return split }
        return view.subviews.lazy.compactMap { findSplit(in: $0) }.first
    }

    private func renderedColor<V: View>(_ view: V) async throws -> NSColor {
        let host = NSHostingView(rootView: view.frame(width: 32, height: 32))
        host.frame = NSRect(x: 0, y: 0, width: 32, height: 32)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // Both the fixture and its oracle use the same window-server color pipeline.
        window.colorSpace = .sRGB
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded()
        let image = try await capture(window)
        return try #require(image.colorAt(x: image.pixelsWide / 2, y: image.pixelsHigh / 2)?.usingColorSpace(.sRGB))
    }

    private func expect(_ image: NSBitmapImageRep, at point: NSPoint, in host: NSView,
                        equals expected: NSColor, label: String) throws {
        let x = Int(point.x * CGFloat(image.pixelsWide) / host.bounds.width)
        let y = Int(point.y * CGFloat(image.pixelsHigh) / host.bounds.height)
        let actual = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        let distance = abs(actual.redComponent - expected.redComponent)
            + abs(actual.greenComponent - expected.greenComponent)
            + abs(actual.blueComponent - expected.blueComponent)
        #expect(distance < 0.025, "\(label) must preserve its established backdrop owner; actual=\(actual), expected=\(expected)")
    }
}
