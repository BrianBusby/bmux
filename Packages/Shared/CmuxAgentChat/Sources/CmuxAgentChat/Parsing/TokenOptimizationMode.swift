import Foundation

/// Controls how aggressively terminal output is compressed before it is shown
/// to token-sensitive consumers.
public enum TokenOptimizationMode: String, CaseIterable, Codable, Sendable {
    /// Forward raw terminal output unchanged while still creating raw-output metadata.
    case off

    /// Compress only low-risk repetitive success output.
    case conservative

    /// Compress recognized command categories while preserving errors and raw output.
    case balanced

    /// Reserved for stronger future reducers; currently follows balanced behavior.
    case aggressive
}
