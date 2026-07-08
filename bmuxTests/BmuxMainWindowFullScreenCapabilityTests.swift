import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite("BmuxMainWindow native fullscreen capability")
struct BmuxMainWindowFullScreenCapabilityTests {
    // bmux creates its main window programmatically and never loaded fullscreen
    // capability from a nib, so it historically relied on AppKit *implicitly*
    // granting `.fullScreenPrimary` to a resizable, titled window. That implicit
    // grant is not reliable across macOS versions / display arrangements: on
    // macOS 26 (Tahoe) a freshly-created BmuxMainWindow reports an empty
    // collection behavior (`rawValue == 0`) and AppKit does NOT treat it as
    // fullscreen-capable — so `toggleFullScreen(_:)`, ⌃⌘F, and the green
    // traffic-light button all fail to enter a native fullscreen Space (the
    // green button only zooms). See issue #5933.
    //
    // A BmuxMainWindow must therefore *declare* `.fullScreenPrimary` itself so
    // native fullscreen is reachable regardless of the OS's implicit default.
    @Test func mainWindowDeclaresFullScreenPrimaryCapability() {
        let window = BmuxMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer {
            window.orderOut(nil)
            window.close()
        }

        #expect(
            window.collectionBehavior.contains(.fullScreenPrimary),
            "Main window must declare .fullScreenPrimary so native fullscreen is reachable"
        )
        #expect(
            !window.collectionBehavior.contains(.fullScreenNone),
            "Main window must never carry .fullScreenNone, which suppresses native fullscreen"
        )
    }

    // The capability decision is a pure, screen-agnostic transform so it runs
    // deterministically on CI regardless of the test host's display setup.

    @Test func canonicalBehaviorAddsFullScreenPrimaryToEmptyBehavior() {
        let result = BmuxMainWindow.canonicalCollectionBehavior([])
        #expect(result.contains(.fullScreenPrimary))
        #expect(!result.contains(.fullScreenNone))
    }

    @Test func canonicalBehaviorDropsStaleFullScreenNone() {
        let result = BmuxMainWindow.canonicalCollectionBehavior([.fullScreenNone])
        #expect(result.contains(.fullScreenPrimary))
        #expect(!result.contains(.fullScreenNone))
    }

    @Test func canonicalBehaviorPreservesUnrelatedBehaviorBits() {
        // The window factory may layer `.fullScreenDisallowsTiling` on top when
        // spawning out of an existing fullscreen Space; canonicalization must
        // not clobber that (or any other unrelated bit).
        let base: NSWindow.CollectionBehavior = [.fullScreenDisallowsTiling, .moveToActiveSpace]
        let result = BmuxMainWindow.canonicalCollectionBehavior(base)
        #expect(result.contains(.fullScreenPrimary))
        #expect(result.contains(.fullScreenDisallowsTiling))
        #expect(result.contains(.moveToActiveSpace))
    }

    @Test func canonicalBehaviorIsIdempotent() {
        let once = BmuxMainWindow.canonicalCollectionBehavior([])
        let twice = BmuxMainWindow.canonicalCollectionBehavior(once)
        #expect(once == twice)
    }
}
