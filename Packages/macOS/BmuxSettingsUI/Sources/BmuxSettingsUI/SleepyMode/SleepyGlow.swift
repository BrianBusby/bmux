import Foundation

/// Background glow gradient behind the Sleepy Mode scene.
public enum SleepyGlow: String, CaseIterable, Identifiable, Sendable {
    /// Flat near-black.
    case black
    /// Deep midnight blue.
    case midnight
    /// bmux-branded blue glow.
    case bmux
    /// Green aurora glow.
    case aurora
    /// Warm sunset glow.
    case sunset
    /// Cool ocean glow.
    case ocean
    /// The user's own background color (see `customBackground`).
    case custom

    /// Stable identity for `Identifiable` (the raw string value).
    public var id: String { rawValue }
}
