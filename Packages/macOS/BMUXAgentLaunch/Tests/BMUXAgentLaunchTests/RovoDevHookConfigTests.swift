import BMUXAgentLaunch
import Testing

@Suite("RovoDevHookConfig")
struct RovoDevHookConfigTests {
    @Test("Installs into direct eventHooks events child only")
    func installsIntoDirectEventHooksEventsChildOnly() {
        let existing = """
        eventHooks:
          nested:
            events:
              - name: user_hook
                commands:
                  - command: "echo user"

        """

        let events = [
            RovoDevHookConfig.Event(
                name: "on_complete",
                command: "bmux hooks rovodev stop"
            ),
        ]
        let installed = RovoDevHookConfig.installing(events: events, in: existing)

        #expect(installed.contains("eventHooks:\n  # bmux hooks rovodev begin\n  events:"))
        #expect(installed.contains("    events:\n      - name: user_hook"))
        #expect(RovoDevHookConfig.uninstalling(from: installed) == existing)
    }

    @Test("Dangling bmux marker does not drop following YAML")
    func danglingMarkerDoesNotDropFollowingYAML() {
        let existing = """
        eventHooks:
          events:
            # bmux hooks rovodev begin
        sessions:
          persistenceDir: /tmp/rovo

        """

        let events = [
            RovoDevHookConfig.Event(
                name: "on_complete",
                command: "bmux hooks rovodev stop"
            ),
        ]
        let installed = RovoDevHookConfig.installing(events: events, in: existing)
        let uninstalled = RovoDevHookConfig.uninstalling(from: existing)

        #expect(installed.contains("sessions:\n  persistenceDir: /tmp/rovo"))
        #expect(uninstalled.contains("sessions:\n  persistenceDir: /tmp/rovo"))
    }
}
