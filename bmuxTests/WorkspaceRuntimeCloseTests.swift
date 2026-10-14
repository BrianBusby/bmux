import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct WorkspaceRuntimeCloseTests {
    @Test func confirmedCloseDetachesTheRealRuntimeAndClosesItsLifecycle() async throws {
        let fixture = try WorkspaceRuntimeCloseFixture()
        defer { fixture.close() }
        try await fixture.prepareRuntime()
        fixture.panel.surface.setNeedsConfirmCloseOverrideForTesting(true)
        fixture.manager.confirmCloseHandler = { _, _, _ in true }

        #expect(fixture.manager.closeWorkspaceWithConfirmation(fixture.workspace))
        #expect(fixture.manager.tabs.count == 1)
        #expect(!fixture.manager.tabs.contains { $0.id == fixture.workspace.id })
        #expect(fixture.panel.surface.surface == nil)
        #expect(fixture.panel.surface.portalBindingStateLabel() == "closed")
        fixture.panel.surface.teardownSurface()
        #expect(fixture.panel.surface.surface == nil)
        #expect(fixture.panel.surface.portalBindingStateLabel() == "closed")
    }
}
