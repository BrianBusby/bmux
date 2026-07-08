public import SwiftUI

/// Adds bmux font magnification values to SwiftUI environment lookups.
public extension EnvironmentValues {
    /// The current clamped global font magnification percent.
    ///
    /// bmux scene roots should inject this value with
    /// ``View/bmuxFontMagnificationEnvironment()`` so repeated row labels can
    /// read a pure environment value instead of each subscribing to
    /// `UserDefaults`.
    var bmuxGlobalFontMagnificationPercent: Int {
        get { self[BmuxGlobalFontMagnificationPercentKey.self] }
        set { self[BmuxGlobalFontMagnificationPercentKey.self] = GlobalFontMagnification.clamp(newValue) }
    }
}
