import BmuxTerminalCore

/// App-target alias for ``BmuxTerminalCore/GhosttyConfig``, lifted into
/// BmuxTerminalCore in stack D tranche A. Keeps every `GhosttyConfig` call site
/// (and `GhosttyConfig.ColorSchemePreference` / `GhosttyConfig.UserAppearanceConfigSummary`
/// member lookups) byte-identical across the app target.
typealias GhosttyConfig = BmuxTerminalCore.GhosttyConfig
