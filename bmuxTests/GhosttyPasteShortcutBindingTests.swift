import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct GhosttyPasteShortcutBindingTests {
    @Test(arguments: [(false, false), (true, false), (false, true)])
    func menuMissUsesConfiguredBinding(shift: Bool, released: Bool) async throws {
        let fixture = GhosttyPasteShortcutFixture(timeout: .seconds(3))
        defer { fixture.close() }
        let view = try await fixture.prepare()
        #expect(view.terminalSurface === fixture.surface)
        #expect(fixture.surface.surface != nil)

        let result = try fixture.dispatch(shift: shift, view: view) {
            if released {
                fixture.surface.releaseSurfaceForTesting()
                #expect(fixture.surface.surface == nil)
            }
        }
        #expect(result.consumed)
        // Menu misses intentionally defer to Ghostty so custom paste bindings win.
        #expect(result.forwardedKeyPresses == 1)
        #expect(fixture.surface.surface != nil)

        let output = try await fixture.nextOutput()
        let expected = shift ? "SHIFT_OVERRIDE" : "PLAIN_OVERRIDE"
        #expect(output == Data(expected.utf8))
    }
}
