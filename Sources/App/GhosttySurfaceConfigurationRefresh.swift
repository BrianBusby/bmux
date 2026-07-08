@MainActor
enum GhosttySurfaceConfigurationRefresh {
    nonisolated static let forceRefreshReason = "appDelegate.refreshAfterGhosttyConfigReload"
    nonisolated static let bmuxThemeReloadLegacySource = "distributed.bmux.themes"
    nonisolated static let bmuxThemeReloadPreviewSource = "distributed.bmux.themes.preview"
    nonisolated static let bmuxThemeReloadFinalSource = "distributed.bmux.themes.final"
    nonisolated static let bmuxThemePreviewReloadDebounceMilliseconds = 180

    nonisolated static func bmuxThemeReloadSource(phase: String?) -> String {
        switch phase {
        case "final", "apply":
            return bmuxThemeReloadFinalSource
        case "preview":
            return bmuxThemeReloadPreviewSource
        default:
            return bmuxThemeReloadLegacySource
        }
    }

    nonisolated static func shouldDebounceBmuxThemeReload(source: String) -> Bool {
        switch source {
        case bmuxThemeReloadLegacySource, bmuxThemeReloadPreviewSource:
            return true
        default:
            return false
        }
    }

    nonisolated static func isBmuxThemeReloadSource(_ source: String) -> Bool {
        switch source {
        case bmuxThemeReloadLegacySource, bmuxThemeReloadPreviewSource, bmuxThemeReloadFinalSource:
            return true
        default:
            return false
        }
    }

    static func applyAfterAppConfigReload(
        to surface: ghostty_surface_t?,
        source: String,
        reloadSurfaceConfiguration: (ghostty_surface_t, Bool, String) -> Void,
        applySurfaceColorScheme: () -> Void,
        refreshHostBackground: () -> Void,
        forceRefresh: (String) -> Void
    ) {
        if let surface {
            applySurfaceColorScheme()
            reloadSurfaceConfiguration(surface, true, source)
        }
        refreshHostBackground()
        forceRefresh(forceRefreshReason)
    }
}
