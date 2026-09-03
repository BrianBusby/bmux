import CryptoKit
import Foundation

/// Builds deterministic identifiers for engine-owned provenance projections.
struct ProvenanceStableIDFactory: Sendable {
    /// Stable session id for a child agent subsession.
    func subsessionSessionID(
        agentKind: String,
        parentSessionID: String,
        identityKind: String,
        identityValue: String
    ) -> String {
        id(
            prefix: "session",
            value: [
                "subsession",
                agentKind,
                parentSessionID,
                identityKind,
                identityValue,
            ].joined(separator: "\n")
        )
    }

    /// Stable session id for a producer-observed session without an explicit id.
    func sessionID(
        agentKind: String,
        identityKind: String,
        identityValue: String
    ) -> String {
        id(
            prefix: "session",
            value: [
                "session-lifecycle",
                agentKind,
                identityKind,
                identityValue,
            ].joined(separator: "\n")
        )
    }

    /// Stable external identity id for a session identity link.
    func externalIdentityID(system: String, kind: String, externalID: String) -> String {
        id(
            prefix: "identity",
            value: [
                system,
                kind,
                externalID,
            ].joined(separator: "\n")
        )
    }

    /// Stable projection id for a workspace-to-coding-agent-session association.
    func workspaceCodingAgentSessionAssociationID(
        workspaceID: String,
        agentKind: String,
        sessionID: String
    ) -> String {
        id(
            prefix: "workspace-agent-session",
            value: [
                "workspace-coding-agent-session-association",
                workspaceID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                agentKind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                sessionID.trimmingCharacters(in: .whitespacesAndNewlines),
            ].joined(separator: "\n")
        )
    }

    /// Stable event id for one observed lifecycle transition.
    func subsessionLifecycleEventID(
        phase: String,
        childSessionID: String,
        timestamp: Date
    ) -> String {
        let timestampMicroseconds = Int64((timestamp.timeIntervalSince1970 * 1_000_000).rounded())
        return id(
            prefix: "event",
            value: [
                "subsession-lifecycle",
                phase,
                childSessionID,
                String(timestampMicroseconds),
            ].joined(separator: "\n")
        )
    }

    /// Stable event id for one observed producer-neutral lifecycle transition.
    func sessionLifecycleEventID(
        phase: String,
        sessionID: String,
        timestamp: Date
    ) -> String {
        let timestampMicroseconds = Int64((timestamp.timeIntervalSince1970 * 1_000_000).rounded())
        return id(
            prefix: "event",
            value: [
                "session-lifecycle",
                phase,
                sessionID,
                String(timestampMicroseconds),
            ].joined(separator: "\n")
        )
    }

    /// Stable prefixed SHA-256 identifier.
    func id(prefix: String, value: String) -> String {
        "\(prefix)-\(digest(value).prefix(24))"
    }

    private func digest(_ value: String) -> String {
        let hash = SHA256.hash(data: Data(value.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
