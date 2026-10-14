import AppKit
import Testing
@testable import bmux_DEV

@MainActor
extension BrowserInspectorWindowOwnershipTests {
    @Test
    func lifecycleObservationWaitsForQueuedReplacementToFinish() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let observation = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.showDeveloperTools())
        #expect(panel.hideDeveloperTools())
        #expect(!panel.debugDeveloperToolsTransitionsAreSettled)
        try await fixture.waitForTransitions(observation: observation) {
            !panel.isDeveloperToolsVisible()
        }
        #expect(fixture.inspector.showCount == 1)
        #expect(fixture.inspector.closeCount == 1)
    }

    @Test
    func lifecycleObservationHandlesNoChangeWithoutWaitingForAnotherTransition() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let initial = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.showDeveloperTools())
        try await fixture.waitForTransitions(observation: initial) { panel.isDeveloperToolsVisible() }
        let noChange = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.showDeveloperTools())
        #expect(panel.debugDeveloperToolsTransitionsAreSettled)
        try await fixture.waitForTransitions(observation: noChange) { panel.isDeveloperToolsVisible() }
        #expect(fixture.inspector.showCount == 1)
    }

    @Test
    func lifecycleObservationWaitsThroughCloseResolutionReplacement() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let observation = panel.debugDeveloperToolsLifecycleChanges()
        panel.scheduleDetachedDeveloperToolsWindowCloseResolution(source: "test.initial")
        panel.scheduleDetachedDeveloperToolsWindowCloseResolution(source: "test.replacement")
        #expect(!panel.debugDeveloperToolsTransitionsAreSettled)
        try await fixture.waitForTransitions(observation: observation) { !panel.preferredDeveloperToolsVisible }
        #expect(!panel.hasPendingDetachedDeveloperToolsWindowCloseResolution)
        #expect(fixture.inspector.closeCount == 0)
    }

    @Test
    func removingLifecycleObservationFinishesOnlyThatSubscriber() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let removed = panel.debugDeveloperToolsLifecycleChanges()
        let retained = panel.debugDeveloperToolsLifecycleChanges()
        panel.debugRemoveDeveloperToolsLifecycleObserver(removed.id)
        try await fixture.waitForObservationEnd(removed)
        #expect(panel.showDeveloperTools())
        try await fixture.waitForTransitions(observation: retained) { panel.isDeveloperToolsVisible() }
        #expect(fixture.inspector.showCount == 1)
    }

    @Test
    func panelCloseFinishesCurrentAndFutureLifecycleObservations() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let observation = panel.debugDeveloperToolsLifecycleChanges()
        #expect(panel.showDeveloperTools())
        #expect(!panel.debugDeveloperToolsTransitionsAreSettled)
        panel.close()
        try await fixture.waitForObservationEnd(observation)
        #expect(panel.debugDeveloperToolsTransitionsAreSettled)
        #expect(fixture.inspector.closeCount == 1)
        try await fixture.waitForObservationEnd(panel.debugDeveloperToolsLifecycleChanges())
    }

    @Test
    func cancellingLifecycleConsumerLeavesOtherSubscribersActive() async throws {
        let fixture = BrowserInspectorTestFixture()
        let panel = fixture.panel
        defer { fixture.closePanel() }
        let cancelled = panel.debugDeveloperToolsLifecycleChanges()
        let retained = panel.debugDeveloperToolsLifecycleChanges()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let consumer = Task { @MainActor in
            for await _ in cancelled.events {
                startedContinuation.finish()
            }
        }
        defer {
            consumer.cancel()
            startedContinuation.finish()
        }
        // Initial owner invalidation confirms consumption started before cancellation.
        try await fixture.waitForStreamEnd(started)
        consumer.cancel()
        await consumer.value
        try await fixture.waitForObservationEnd(cancelled)
        #expect(panel.showDeveloperTools())
        try await fixture.waitForTransitions(observation: retained) { panel.isDeveloperToolsVisible() }
        #expect(fixture.inspector.showCount == 1)
    }

    @Test
    func observationOwnerDeinitFinishesStreamWithoutExplicitClose() async throws {
        let fixture = BrowserInspectorTestFixture()
        defer { fixture.closePanel() }
        var owner: BrowserDeveloperToolsLifecycleObservation? = BrowserDeveloperToolsLifecycleObservation()
        weak let releasedOwner = owner
        let observation = try #require(owner?.changes())
        owner = nil
        #expect(releasedOwner == nil)
        try await fixture.waitForStreamEnd(observation.events)
    }

}
