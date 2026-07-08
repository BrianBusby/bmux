import Foundation

/// UserDefaults keys for the device presence heartbeat.
///
/// Release default OFF: a stable Mac announces nothing unless the flag is
/// enabled and a service URL is set (the production worker URL ships with the
/// Settings surface as a follow-up). Debug default ON against the dev/staging
/// instance: Debug builds sign into the dev Stack project, which is exactly
/// what `bmux-presence-dev` verifies, so tagged dogfood builds get live
/// presence with zero setup while both defaults stay explicitly overridable.
enum PresenceSettings {
    /// Master gate. Resolved by ``isEnabled(defaults:)``; an explicit value
    /// always wins, otherwise Debug defaults on and Release off.
    static let enabledKey = "presenceHeartbeatEnabled"
    /// Base URL of the presence service (the bmux-presence worker), e.g.
    /// "https://bmux-presence.<account>.workers.dev". Empty means disabled.
    static let serviceURLKey = "presenceServiceURL"
    /// Env override for dev/tagged builds, mirroring BMUX_VM_API_BASE_URL.
    static let serviceURLEnvKey = "BMUX_PRESENCE_BASE_URL"
    /// The dev/staging worker (dev Stack project), the Debug-build default.
    /// See workers/presence/README.md.
    static let debugDefaultServiceURL = "https://bmux-presence-dev.debussy.workers.dev"

    /// The production presence worker (prod Stack project), the Release-build
    /// default so stable bmux can announce presence once the user enables mobile.
    /// See workers/presence/README.md.
    static let productionServiceURL = "https://presence.bmux.dev"

    /// Whether the heartbeat gate is on. An explicitly written value always wins.
    /// With no stored value, presence FOLLOWS the mobile feature: announcing the
    /// Mac's presence only makes sense once the user has enabled iOS pairing/host
    /// (``MobileHostService/isListeningEnabled``), and a user who turns mobile on
    /// expects their phone to see the Mac online. Default (mobile off) => off, for
    /// privacy — the Mac announces nothing until the user opts into mobile.
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) != nil {
            return defaults.bool(forKey: enabledKey)
        }
        return MobileHostService.isListeningEnabled(defaults: defaults)
    }
}
