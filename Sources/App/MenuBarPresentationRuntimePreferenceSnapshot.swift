import AppKit
import Foundation

struct MenuBarPresentationRuntimePreferenceSnapshot: Equatable {
    let menuBarOnlyEnabled: Bool
    let showsMenuBarExtra: Bool
    let shouldInstallMenuBarExtra: Bool
    let activationPolicy: NSApplication.ActivationPolicy
    let workspacePresentationMode: WorkspacePresentationModeSettings.Mode

    static func current(
        defaults: UserDefaults = .standard
    ) -> MenuBarPresentationRuntimePreferenceSnapshot {
        MenuBarPresentationRuntimePreferenceSnapshot(
            menuBarOnlyEnabled: MenuBarOnlySettings.isEnabled(defaults: defaults),
            showsMenuBarExtra: MenuBarExtraSettings.showsMenuBarExtra(defaults: defaults),
            shouldInstallMenuBarExtra: MenuBarExtraSettings.shouldInstallMenuBarExtra(defaults: defaults),
            activationPolicy: MenuBarOnlySettings.activationPolicy(defaults: defaults),
            workspacePresentationMode: WorkspacePresentationModeSettings.mode(defaults: defaults)
        )
    }
}
