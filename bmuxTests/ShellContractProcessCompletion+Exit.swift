import Foundation

extension ShellContractProcessCompletion {
    struct Exit: Sendable {
        let status: Int32
        let observedAt: ContinuousClock.Instant
    }
}
