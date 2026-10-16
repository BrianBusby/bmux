import Foundation

/// Captures native focus-deferral facts before a later AppKit layout can restore geometry.
struct TerminalFocusDeferralObservation {
    let firstResponder: Bool
    let hostDesiredFocus: Bool
    let surfaceDesiredFocus: Bool
    let surfaceSize: NSSize
    let hostSize: NSSize
}
