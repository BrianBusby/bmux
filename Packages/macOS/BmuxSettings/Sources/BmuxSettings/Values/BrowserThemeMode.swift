import Foundation

/// User-selected web-content appearance for the bmux browser.
public enum BrowserThemeMode: String, CaseIterable, Sendable, SettingCodable {
    case system, light, dark
}
