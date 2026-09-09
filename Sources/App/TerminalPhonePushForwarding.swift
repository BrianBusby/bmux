import Foundation

@MainActor
protocol TerminalPhonePushForwarding: AnyObject {
    func willForwardReplacement(defaults: UserDefaults) -> Bool

    @discardableResult
    func forward(_ notification: TerminalNotification, badgeCount: Int) -> Bool

    func forwardDismissed(ids: [String], badgeCount: Int)
}

@MainActor
final class NoopTerminalPhonePushForwarding: TerminalPhonePushForwarding {
    func willForwardReplacement(defaults: UserDefaults) -> Bool { false }

    func forward(_ notification: TerminalNotification, badgeCount: Int) -> Bool { false }

    func forwardDismissed(ids: [String], badgeCount: Int) {}
}

extension PhonePushClient: TerminalPhonePushForwarding {}
