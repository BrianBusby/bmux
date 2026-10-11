import AppKit
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Coverage for ``shouldRespectForeignFirstResponder(_:in:isRightSidebarOwner:)`` — the policy that
/// decides whether an active terminal yields to the window's current first responder or reclaims
/// focus. Regression coverage for issue #5269 (a stranded responder must not block focus).
@MainActor
@Suite struct ForeignFirstResponderPolicyTests {
    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
    }

    private let neverSidebarOwner: (NSResponder) -> Bool = { _ in false }
    private let alwaysSidebarOwner: (NSResponder) -> Bool = { _ in true }

    @Test func respectsInWindowTextEditor() {
        let window = makeWindow()
        let textView = NSTextView(frame: .zero)
        window.contentView?.addSubview(textView)
        #expect(shouldRespectForeignFirstResponder(textView, in: window, isRightSidebarOwner: neverSidebarOwner))
    }

    /// The #5269 regression: a text responder stranded in another window must NOT be respected, so
    /// the terminal can reclaim focus. Without the window-membership check this returns `true`.
    @Test func reclaimsFromStrandedTextEditorInAnotherWindow() {
        let windowA = makeWindow()
        let windowB = makeWindow()
        let textView = NSTextView(frame: .zero)
        windowB.contentView?.addSubview(textView) // belongs to windowB, not windowA
        #expect(!shouldRespectForeignFirstResponder(textView, in: windowA, isRightSidebarOwner: neverSidebarOwner))
    }

    @Test func respectsInWindowRightSidebarOwner() {
        let window = makeWindow()
        let view = NSView(frame: .zero)
        window.contentView?.addSubview(view)
        #expect(shouldRespectForeignFirstResponder(view, in: window, isRightSidebarOwner: alwaysSidebarOwner))
    }

    /// The #5269 regression for the sidebar/dock flavor: a sidebar host stranded in another window
    /// must NOT be respected. Without the window-membership check this returns `true`.
    @Test func reclaimsFromStrandedRightSidebarOwner() {
        let windowA = makeWindow()
        let windowB = makeWindow()
        let view = NSView(frame: .zero)
        windowB.contentView?.addSubview(view)
        #expect(!shouldRespectForeignFirstResponder(view, in: windowA, isRightSidebarOwner: alwaysSidebarOwner))
    }

    @Test func reclaimsFromDetachedResponder() {
        let window = makeWindow()
        let textView = NSTextView(frame: .zero) // never added to a window -> .window is nil
        #expect(!shouldRespectForeignFirstResponder(textView, in: window, isRightSidebarOwner: alwaysSidebarOwner))
    }

    @Test func doesNotRespectPlainInWindowView() {
        let window = makeWindow()
        let view = NSView(frame: .zero)
        window.contentView?.addSubview(view)
        // Neither a text editor nor a sidebar owner: the terminal reclaims focus (existing behavior).
        #expect(!shouldRespectForeignFirstResponder(view, in: window, isRightSidebarOwner: neverSidebarOwner))
    }

    @Test func dedicatedHostMembershipIsSynchronousBeforeSwiftUIFocusRendering() throws {
        let window = makeWindow()
        let owner = WorkspaceSidebarFocusOwner()
        let host = NSHostingView(rootView:
            WorkspaceSidebarFocusScope(usesIntrinsicSize: false, onAttachmentChange: { view, attached in
                if attached { owner.register(view, scope: .rail, in: window) }
                else { owner.unregister(view, scope: .rail) }
            }) {
                VStack {
                    Button("Filters") {}.buttonStyle(.plain).focusable()
                    Button("Active") {}.buttonStyle(.plain).focusable()
                }
            })
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.orderBack(nil)
        defer { window.orderOut(nil) }
        window.recalculateKeyViewLoop()
        for _ in 0..<2 {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48))
            window.sendEvent(event)
            let responder = try #require(window.firstResponder)
            // No layout pass or run-loop drain between native Tab and ownership.
            owner.synchronize(responder: responder, in: window)
            #expect(owner.owns(responder, in: window))
            host.layoutSubtreeIfNeeded()
        }
    }

    @Test func exactHostMembershipRejectsUnrelatedAndStrandedResponders() {
        let window = makeWindow()
        let otherWindow = makeWindow()
        let owner = WorkspaceSidebarFocusOwner()
        let host = NSView()
        let responder = SidebarTestResponder()
        let unrelated = SidebarTestResponder()
        window.contentView?.addSubview(host)
        host.addSubview(responder)
        window.contentView?.addSubview(unrelated)
        owner.register(host, scope: .rail, in: window)
        owner.synchronize(responder: responder, in: window)
        #expect(owner.owns(responder, in: window))
        #expect(!owner.owns(unrelated, in: window))
        owner.synchronize(responder: unrelated, in: window)
        #expect(!owner.owns(responder, in: window))
        owner.synchronize(responder: responder, in: window)
        otherWindow.contentView?.addSubview(responder)
        #expect(!owner.owns(responder, in: window))
        #expect(!shouldRespectForeignFirstResponder(responder, in: window,
            isRightSidebarOwner: alwaysSidebarOwner, isWorkspaceSidebarOwner: { _ in true }))
    }

    @Test func registeredPopoverUsesExactChildAndRevokesAcrossReparenting() {
        let window = makeWindow()
        let otherWindow = makeWindow()
        let popover = makeWindow()
        let owner = WorkspaceSidebarFocusOwner()
        let host = NSView()
        let responder = SidebarTestResponder()
        let unrelated = SidebarTestResponder()
        popover.contentView?.addSubview(host)
        host.addSubview(responder)
        popover.contentView?.addSubview(unrelated)
        window.addChildWindow(popover, ordered: .above)
        defer { popover.parent?.removeChildWindow(popover) }
        owner.register(host, scope: .filterPopover, in: window)
        owner.synchronize(responder: responder, in: window)
        #expect(shouldRespectForeignFirstResponder(responder, in: window,
            isRightSidebarOwner: neverSidebarOwner, isWorkspaceSidebarOwner: { owner.owns($0, in: window) }))
        #expect(!owner.owns(unrelated, in: window))
        #expect(!owner.owns(responder, in: popover))
        window.removeChildWindow(popover)
        window.addChildWindow(popover, ordered: .above)
        #expect(!owner.owns(responder, in: window))
        // AppKit can report successful makeFirstResponder with the same value;
        // this is not a fresh focus transition after reparenting.
        owner.synchronize(responder: responder, in: window)
        #expect(!owner.owns(responder, in: window))
        owner.synchronize(responder: nil, in: window)
        owner.synchronize(responder: responder, in: window)
        #expect(owner.owns(responder, in: window))
        window.removeChildWindow(popover)
        otherWindow.addChildWindow(popover, ordered: .above)
        owner.synchronize(responder: responder, in: window)
        #expect(!owner.owns(responder, in: window))
        #expect(!shouldRespectForeignFirstResponder(responder, in: window,
            isRightSidebarOwner: alwaysSidebarOwner, isWorkspaceSidebarOwner: { owner.owns($0, in: window) }))
    }

    @Test func oldHostTeardownCannotClearAReplacementAndDisabledScopeRevokesFocus() {
        let window = makeWindow()
        let owner = WorkspaceSidebarFocusOwner()
        let oldHost = NSView()
        let host = NSView()
        let responder = SidebarTestResponder()
        window.contentView?.addSubview(oldHost)
        window.contentView?.addSubview(host)
        host.addSubview(responder)
        owner.register(oldHost, scope: .rail, in: window)
        owner.register(host, scope: .rail, in: window)
        owner.synchronize(responder: responder, in: window)
        owner.unregister(oldHost, scope: .rail)
        #expect(owner.owns(responder, in: window))
        owner.unregister(host, scope: .rail) // Scope disable uses this same path.
        #expect(!owner.owns(responder, in: window))
        owner.register(host, scope: .rail, in: window)
        #expect(!owner.owns(responder, in: window))
    }

    @Test func nativeHostReportsDetachBeforeLosingItsWindow() {
        let first = makeWindow()
        let second = makeWindow()
        let host = WorkspaceSidebarHostingView(rootView: AnyView(Color.clear))
        var events: [(NSWindow?, Bool)] = []
        host.onAttachmentChange = { view, attached in events.append((view.window, attached)) }
        first.contentView?.addSubview(host)
        events.removeAll()
        second.contentView?.addSubview(host)
        #expect(events.first?.0 === first)
        #expect(events.first?.1 == false)
        #expect(events.last?.0 === second)
        #expect(events.last?.1 == true)
        WorkspaceSidebarFocusScope<Color>.dismantleNSView(host, coordinator: ())
        #expect(events.last?.1 == false)
        #expect(host.onAttachmentChange == nil)
    }

    @Test func hostingBoundaryPreservesLocalStateEnvironmentAndIntrinsicResize() throws {
        let window = makeWindow()
        var snapshots: [(UUID, ColorScheme, Bool, LayoutDirection, String)] = []
        var nativeHosts: [NSView] = []
        func root(height: CGFloat, enabled: Bool) -> some View {
            WorkspaceSidebarFocusScope(usesIntrinsicSize: true, onAttachmentChange: { host, attached in
                if attached { nativeHosts.append(host) }
            }) {
                SidebarScopeFixture(height: height) { snapshots.append($0) }
            }
            .environment(\.colorScheme, .dark)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ja"))
            .disabled(!enabled)
        }
        let outer = NSHostingView(rootView: root(height: 40, enabled: true))
        window.contentView = outer
        outer.layoutSubtreeIfNeeded()
        let first = try #require(snapshots.last)
        let host = try #require(nativeHosts.last)
        #expect(first.1 == .dark && first.2 && first.3 == .rightToLeft && first.4 == "ja")
        #expect(host.fittingSize.height == 40)
        outer.rootView = root(height: 80, enabled: false)
        outer.layoutSubtreeIfNeeded()
        let updated = try #require(snapshots.last)
        #expect(updated.0 == first.0)
        #expect(!updated.2)
        #expect(nativeHosts.allSatisfy { $0 === host })
        #expect(host.fittingSize.height == 80)
    }

    @Test func nativeHostOutsetPreservesContentWidthAndAcceptsEdgeHits() throws {
        let window = makeWindow()
        var nativeHost: NSView?
        let gutter: CGFloat = 14
        let outer = NSHostingView(rootView:
            WorkspaceSidebarFocusScope(usesIntrinsicSize: false, onAttachmentChange: { host, attached in
                if attached { nativeHost = host }
            }) {
                Color.clear.frame(height: 40).padding(.horizontal, gutter)
            }
            .padding(.horizontal, -gutter)
            .frame(width: 100, height: 40))
        window.contentView = outer
        outer.layoutSubtreeIfNeeded()
        let host = try #require(nativeHost)
        #expect(outer.fittingSize.width == 100)
        #expect(host.bounds.width == 100 + 2 * gutter)
        let pointOutsideVisibleContent = NSPoint(x: host.bounds.maxX - gutter + 3, y: host.bounds.midY)
        let pointInParent = host.convert(pointOutsideVisibleContent, to: host.superview)
        #expect(host.hitTest(pointInParent) != nil)
    }

    @Test func nativePopoverObservationDoesNotRetainOwner() {
        let window = makeWindow()
        let popover = makeWindow()
        let host = NSView()
        popover.contentView?.addSubview(host)
        window.addChildWindow(popover, ordered: .above)
        var owner: WorkspaceSidebarFocusOwner? = WorkspaceSidebarFocusOwner()
        let released = { [weak owner] in owner == nil }
        owner?.register(host, scope: .filterPopover, in: window)
        owner = nil
        #expect(released())
        window.removeChildWindow(popover)
    }
}

private final class SidebarTestResponder: NSView {
    override var acceptsFirstResponder: Bool { true }
}
