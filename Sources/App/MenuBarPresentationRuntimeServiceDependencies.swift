import AppKit
import Foundation

@MainActor
struct MenuBarPresentationRuntimeServiceDependencies {
    var validateRequiredRuntime: () -> MenuBarPresentationRuntimeOperationResult
    var normalizeLegacyStoredPreference: () -> Void
    var currentPreferenceSnapshot: () -> MenuBarPresentationRuntimePreferenceSnapshot
    var setMenuBarOnlyPreference: (Bool) -> Bool
    var currentActivationPolicy: () -> NSApplication.ActivationPolicy
    var setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool
    var makePreferencesObserver: (@escaping @MainActor () -> Void) -> NSObjectProtocol
    var removePreferencesObserver: (NSObjectProtocol) -> Void
    var setMenuRefreshHandler: ((@MainActor () -> Void)?) -> Void

    static func production() -> MenuBarPresentationRuntimeServiceDependencies {
        MenuBarPresentationRuntimeServiceDependencies(
            validateRequiredRuntime: { .ready },
            normalizeLegacyStoredPreference: {
                MenuBarOnlySettings.normalizeLegacyStoredPreference()
            },
            currentPreferenceSnapshot: {
                MenuBarPresentationRuntimePreferenceSnapshot.current()
            },
            setMenuBarOnlyPreference: { enabled in
                MenuBarOnlySettings.setEnabled(enabled)
                return true
            },
            currentActivationPolicy: {
                NSApp.activationPolicy()
            },
            setActivationPolicy: { policy in
                NSApp.setActivationPolicy(policy)
            },
            makePreferencesObserver: { handler in
                NotificationCenter.default.addObserver(
                    forName: UserDefaults.didChangeNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    MainActor.assumeIsolated {
                        handler()
                    }
                }
            },
            removePreferencesObserver: { observer in
                NotificationCenter.default.removeObserver(observer)
            },
            setMenuRefreshHandler: { handler in
                SleepyModeController.shared.onStateChange = handler
            }
        )
    }
}
