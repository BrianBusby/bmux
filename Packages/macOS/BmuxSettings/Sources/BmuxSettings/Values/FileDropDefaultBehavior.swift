import Foundation

/// What bmux does when a file is dragged onto a terminal pane.
///
/// Cases match the legacy app exactly so the existing on-disk
/// preference round-trips. The default is `text` (insert the file
/// path as terminal text).
public enum FileDropDefaultBehavior: String, CaseIterable, Sendable, SettingCodable {
    /// Insert the file path as terminal text. Shift inverts on drop.
    case text
    /// Split-and-open in bmux's preview viewer.
    case preview
}
