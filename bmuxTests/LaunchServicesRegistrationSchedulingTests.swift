import AppKit
import Carbon.HIToolbox
import Testing
@testable import bmux_DEV

/// Owns the temporary delegate only while exercising deferred registration scheduling.
@MainActor
@Suite
struct LaunchServicesRegistrationSchedulingTests {
    @Test
    func scheduleLaunchServicesRegistrationDefersRegisterWork() {
        _ = NSApplication.shared
        let previousApp = AppDelegate.shared
        defer {
            AppDelegate.shared = previousApp
            if let previousApp {
                GhosttyApp.terminalSurfaceRegistry.attachRouteRetirer(previousApp)
            }
        }
        let app = AppDelegate()
        var scheduledWork: (@Sendable () -> Void)?
        var registerCallCount = 0

        app.scheduleLaunchServicesBundleRegistrationForTesting(
            bundleURL: URL(fileURLWithPath: "/tmp/../tmp/bmux-launch-services-test.app"),
            scheduler: { work in
                scheduledWork = work
            },
            register: { _ in
                registerCallCount += 1
                return noErr
            }
        )

        #expect(registerCallCount == 0, "Registration should not run inline on the startup call path")
        #expect(scheduledWork != nil, "Registration work should be handed to the scheduler")
        scheduledWork?()
        #expect(registerCallCount == 1)
    }
}
