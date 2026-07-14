import Foundation

/// A stable semantic event type stored in the provenance ledger.
///
/// The type is a string-backed value instead of a closed enum so storage can
/// preserve newer event names even when an older caller only understands the
/// core V1 set.
struct WorkProvenanceEventType: Codable, Equatable, Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    /// The raw event type value.
    let rawValue: String

    /// Creates an event type from a raw value.
    ///
    /// - Parameter rawValue: Stable event type name.
    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an event type from a string literal.
    ///
    /// - Parameter value: Stable event type name.
    init(stringLiteral value: String) {
        self.rawValue = value
    }

    /// Bmux proposed a work-item assignment.
    static let workItemProposed = Self(rawValue: "work_item_proposed")

    /// An agent confirmed or corrected a work-item assignment.
    static let workItemConfirmed = Self(rawValue: "work_item_confirmed")

    /// A session began contributing to a work item.
    static let contributionStarted = Self(rawValue: "contribution_started")

    /// A contribution recorded a progress checkpoint.
    static let progressCheckpoint = Self(rawValue: "progress_checkpoint")

    /// Bmux detected likely overlap or conflict.
    static let conflictDetected = Self(rawValue: "conflict_detected")

    /// Sessions recorded an advisory coordination agreement.
    static let coordinationAgreement = Self(rawValue: "coordination_agreement")

    /// A session closed its contribution.
    static let contributionCompleted = Self(rawValue: "contribution_completed")

    /// Bmux observed repository metadata.
    static let repositoryObserved = Self(rawValue: "repository_observed")

    /// Bmux observed worktree metadata.
    static let worktreeObserved = Self(rawValue: "worktree_observed")

    /// Bmux observed session metadata.
    static let sessionObserved = Self(rawValue: "session_observed")
}
