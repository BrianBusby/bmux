import Foundation

@_spi(BmuxHostTransport)
/// Result returned by BMUX for a sidebar host action request.
public struct BmuxSidebarActionResult: Codable, Equatable, Sendable {
    /// Whether BMUX accepted and applied the action.
    public var accepted: Bool

    /// Optional host-supplied result or rejection message.
    public var message: String?

    /// Structured reason when the action was rejected.
    public var rejectionReason: BmuxSidebarActionRejectionReason?

    /// Creates an action result.
    public init(
        accepted: Bool,
        message: String? = nil,
        rejectionReason: BmuxSidebarActionRejectionReason? = nil
    ) {
        self.accepted = accepted
        self.message = message
        self.rejectionReason = accepted ? nil : rejectionReason
    }

    /// Successful action result.
    public static let accepted = BmuxSidebarActionResult(accepted: true)

    /// Creates a rejected action result with a displayable message.
    public static func rejected(
        _ message: String,
        reason: BmuxSidebarActionRejectionReason = .rejected
    ) -> BmuxSidebarActionResult {
        BmuxSidebarActionResult(accepted: false, message: message, rejectionReason: reason)
    }

    /// Rejected action result used when the caller cancels an in-flight request.
    public static let cancelled = BmuxSidebarActionResult(
        accepted: false,
        message: "Extension action was cancelled",
        rejectionReason: .cancelled
    )
}

@_spi(BmuxHostTransport)
/// Machine-readable reason BMUX rejected a sidebar action.
public enum BmuxSidebarActionRejectionReason: String, Codable, Equatable, Sendable {
    /// Generic host rejection.
    case rejected

    /// The caller cancelled the action before the host completed it.
    case cancelled
}

/// Error thrown by typed `BmuxSidebarHost` action helpers.
public enum BmuxSidebarActionError: Error, Equatable, Sendable {
    /// BMUX rejected the action with a displayable message.
    case rejected(String)

    /// The caller cancelled the action before completion.
    case cancelled
}
