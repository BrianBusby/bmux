import AppKit
import Testing
import BmuxTerminal

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct WorkspaceTerminalFocusRecoverySwiftTests {
#if DEBUG
    @Test
    func hiddenTinyFirstResponderReappliesGhosttyFocusAfterGeometrySettles() async throws {
        try await WorkspaceTerminalFocusRecoveryFixture.run(dock: false) { fixture in
            let panel = fixture.panel
            let window = fixture.window
            try await fixture.prepare(visible: true)
            let surfaceView = panel.hostedView.surfaceView
            window.makeFirstResponder(nil)
            panel.surface.setFocus(false)
            #expect(!panel.surface.debugDesiredFocusState())

            surfaceView.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
            #expect(window.makeFirstResponder(surfaceView))
            #expect(panel.hostedView.isSurfaceViewFirstResponder())
            #expect(panel.hostedView.debugRenderStats().desiredFocus)
            #expect(
                !panel.surface.debugDesiredFocusState(),
                "Hidden/tiny first-responder handoff should defer Ghostty focus until geometry is usable"
            )

            try await fixture.deliverQueuedFocus()
            #expect(
                !panel.surface.debugDesiredFocusState(),
                "The first deferred apply can fire while geometry is still unusable"
            )

            surfaceView.frame = NSRect(x: 0, y: 0, width: 180, height: 220)
            surfaceView.layoutSubtreeIfNeeded()
            try await fixture.deliverQueuedFocus()

            #expect(
                panel.surface.debugDesiredFocusState(),
                "Deferred focus reconciliation should reapply Ghostty focus once geometry becomes usable"
            )
        }
    }

    @Test
    func forcedReparentFocusClearRetriesWhenSurfaceGeometryIsStillTiny() async throws {
        try await WorkspaceTerminalFocusRecoveryFixture.run(dock: false) { fixture in
            let panel = fixture.panel
            let window = fixture.window
            try await fixture.prepare(visible: true)
            let surfaceView = panel.hostedView.surfaceView
            window.makeFirstResponder(nil)
            panel.surface.setFocus(false)
            surfaceView.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
            panel.hostedView.suppressReparentFocus()
            #expect(panel.hostedView.debugIsSuppressingReparentFocusForTesting())
            #expect(window.makeFirstResponder(surfaceView))
            try await fixture.deliverQueuedFocus()
            #expect(!panel.hostedView.debugHasPendingAutomaticFirstResponderApplyForTesting())
            #expect(!panel.surface.debugDesiredFocusState())

            panel.hostedView.clearSuppressReparentFocus()

            #expect(
                panel.hostedView.debugHasPendingAutomaticFirstResponderApplyForTesting(),
                "Forced reparent focus reassert should keep a deferred retry queued while surface geometry is tiny"
            )
            #expect(!panel.surface.debugDesiredFocusState())

            surfaceView.frame = NSRect(x: 0, y: 0, width: 180, height: 220)
            try await fixture.deliverQueuedFocus()

            #expect(
                panel.surface.debugDesiredFocusState(),
                "Forced reparent focus reassert should recover once the queued retry sees usable surface geometry"
            )
        }
    }

    @Test
    func alreadyFirstResponderReparentFocusClearWaitsForSurfaceGeometry() async throws {
        try await WorkspaceTerminalFocusRecoveryFixture.run(dock: false) { fixture in
            let panel = fixture.panel
            let window = fixture.window
            try await fixture.prepare(visible: true)
            let surfaceView = panel.hostedView.surfaceView
            #expect(window.makeFirstResponder(surfaceView))
            #expect(panel.hostedView.isSurfaceViewFirstResponder())
            panel.surface.setFocus(false)
            #expect(!panel.surface.debugDesiredFocusState())

            surfaceView.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
            panel.hostedView.suppressReparentFocus()
            panel.hostedView.clearSuppressReparentFocus()

            #expect(
                panel.hostedView.debugHasPendingAutomaticFirstResponderApplyForTesting(),
                "Already-first-responder reparent clear should queue a retry instead of focusing a tiny surface"
            )
            #expect(!panel.surface.debugDesiredFocusState())

            surfaceView.frame = NSRect(x: 0, y: 0, width: 180, height: 220)
            try await fixture.deliverQueuedFocus()

            #expect(
                panel.surface.debugDesiredFocusState(),
                "Already-first-responder reparent clear should recover after surface geometry becomes usable"
            )
        }
    }

    @Test
    func automaticApplyDoesNotBypassHiddenTinyFirstResponderDeferral() async throws {
        try await WorkspaceTerminalFocusRecoveryFixture.run(dock: false) { fixture in
            let panel = fixture.panel
            let window = fixture.window
            try await fixture.prepare(visible: false)
            let surfaceView = panel.hostedView.surfaceView
            // Initial workspace reconciliation may restore selected-panel visibility.
            panel.hostedView.setVisibleInUI(false)
            #expect(!panel.hostedView.debugPortalVisibleInUI)
            window.makeFirstResponder(nil)
            panel.surface.setFocus(false)
            surfaceView.frame = NSRect(x: 0, y: 0, width: 0, height: 0)

            panel.hostedView.setVisibleInUI(true)
            try await fixture.deliverQueuedFocus()

            #expect(panel.hostedView.isSurfaceViewFirstResponder())
            #expect(panel.hostedView.debugRenderStats().desiredFocus)
            #expect(
                !panel.surface.debugDesiredFocusState(),
                "Automatic first-responder apply must not mark Ghostty focused while hidden/tiny deferral is pending"
            )

            surfaceView.frame = NSRect(x: 0, y: 0, width: 180, height: 220)
            surfaceView.layoutSubtreeIfNeeded()
            panel.hostedView.layoutSubtreeIfNeeded()
            try await fixture.deliverQueuedFocus()

            #expect(
                panel.surface.debugDesiredFocusState(),
                "Pending automatic deferral should reapply Ghostty focus once the surface geometry is usable"
            )
        }
    }

    @Test
    func findTerminalRestorePreservesHiddenTinyFirstResponderDeferral() async throws {
        try await WorkspaceTerminalFocusRecoveryFixture.run(dock: false) { fixture in
            let panel = fixture.panel
            let window = fixture.window
            let searchState = TerminalSurface.SearchState(needle: "needle")
            panel.surface.searchState = searchState
            panel.hostedView.setSearchOverlay(searchState: searchState)
            panel.hostedView.preparePanelFocusIntentForActivation(.surface)
            try await fixture.prepare(visible: false)
            let surfaceView = panel.hostedView.surfaceView
            // Initial workspace reconciliation may restore selected-panel visibility.
            panel.hostedView.setVisibleInUI(false)
            #expect(!panel.hostedView.debugPortalVisibleInUI)
            window.makeFirstResponder(nil)
            panel.surface.setFocus(false)
            surfaceView.frame = NSRect(x: 0, y: 0, width: 0, height: 0)

            panel.hostedView.setVisibleInUI(true)
            try await fixture.deliverQueuedFocus()

            #expect(panel.hostedView.isSurfaceViewFirstResponder())
            #expect(
                !panel.surface.debugDesiredFocusState(),
                "Find terminal restore must not drop hidden/tiny focus recovery before Ghostty focus is reapplied"
            )

            surfaceView.frame = NSRect(x: 0, y: 0, width: 180, height: 220)
            surfaceView.layoutSubtreeIfNeeded()
            panel.hostedView.layoutSubtreeIfNeeded()
            try await fixture.deliverQueuedFocus()

            #expect(
                panel.surface.debugDesiredFocusState(),
                "Find terminal restore should reassert Ghostty focus after deferred geometry recovery"
            )
        }
    }

    @Test
    func rightSidebarDockHiddenTinyFirstResponderReappliesGhosttyFocusAfterGeometrySettles() async throws {
        try await WorkspaceTerminalFocusRecoveryFixture.run(dock: true) { fixture in
            let panel = fixture.panel
            let window = fixture.window
            try await fixture.prepare(visible: true)
            let surfaceView = panel.hostedView.surfaceView
            window.makeFirstResponder(nil)
            panel.surface.setFocus(false)
            #expect(!panel.surface.debugDesiredFocusState())

            // The host owns child size; constrain it so queued layout preserves tiny geometry.
            panel.hostedView.frame.size = .zero
            panel.hostedView.reconcileGeometryNow()
            surfaceView.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
            #expect(surfaceView.bounds.size == .zero)
            #expect(window.makeFirstResponder(surfaceView))
            #expect(panel.hostedView.isSurfaceViewFirstResponder())
            #expect(panel.hostedView.debugRenderStats().desiredFocus)
            #expect(
                !panel.surface.debugDesiredFocusState(),
                "Right-sidebar dock handoff should defer Ghostty focus until geometry is usable"
            )

            try await fixture.deliverQueuedFocus()
            #expect(
                !panel.surface.debugDesiredFocusState(),
                "The dock deferred apply can fire while geometry is still unusable"
            )

            panel.hostedView.frame.size = NSSize(width: 180, height: 220)
            panel.hostedView.reconcileGeometryNow()
            surfaceView.frame = NSRect(x: 0, y: 0, width: 180, height: 220)
            surfaceView.layoutSubtreeIfNeeded()
            panel.hostedView.layoutSubtreeIfNeeded()
            try await fixture.deliverQueuedFocus()

            #expect(
                panel.surface.debugDesiredFocusState(),
                "Right-sidebar dock deferred focus reconciliation should reapply Ghostty focus once geometry becomes usable"
            )
        }
    }

    @Test
    func rightSidebarDockAutomaticVisibilityApplyDoesNotStealMainTerminalFocus() async throws {
        try await WorkspaceTerminalFocusRecoveryFixture.run(dock: true) { fixture in
            let window = fixture.window
            let dockPanel = fixture.panel
            let mainPanel = fixture.makeMainPeer()
            try fixture.attach(mainPanel, visible: true)
            try await fixture.prepare(visible: false)
            let mainSurfaceView = mainPanel.hostedView.surfaceView
            #expect(window.makeFirstResponder(mainSurfaceView))
            #expect(window.firstResponder === mainSurfaceView)
            dockPanel.surface.setFocus(false)
            #expect(!dockPanel.surface.debugDesiredFocusState())

            dockPanel.hostedView.setVisibleInUI(true)
            dockPanel.hostedView.layoutSubtreeIfNeeded()
            try await fixture.deliverQueuedFocus()

            #expect(window.firstResponder === mainSurfaceView)
            #expect(!dockPanel.hostedView.debugRenderStats().desiredFocus)
            #expect(
                !dockPanel.surface.debugDesiredFocusState(),
                "Dock visibility/readiness applies must not steal keyboard focus without an active hidden/tiny handoff"
            )
        }
    }

#endif
}
