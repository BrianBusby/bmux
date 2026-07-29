import Foundation

/// Read-only diagnostic comparing live execution telemetry with bounded Current State facts.
public struct ExecutionTelemetryObservationDiagnostic: Sendable, Equatable {
    /// Session id requested by the caller.
    public let sessionID: String

    /// Bounded mismatch rows. An empty array means the compared facts match.
    public let mismatches: [ExecutionTelemetryObservationMismatch]

    /// Text status for JSON renderers.
    public var status: String {
        mismatches.isEmpty ? "matched" : "mismatched"
    }

    /// Creates a diagnostic result.
    ///
    /// - Parameters:
    ///   - sessionID: Session id requested by the caller.
    ///   - mismatches: Bounded mismatch rows.
    public init(sessionID: String, mismatches: [ExecutionTelemetryObservationMismatch]) {
        self.sessionID = sessionID
        self.mismatches = mismatches
    }

    /// Compares live projection state with bounded Current State session facts.
    ///
    /// This comparison is intentionally observational and read-only. It checks
    /// only session presence, provider identity, and broad lifecycle presence.
    ///
    /// - Parameters:
    ///   - sessionID: Session id requested by the caller.
    ///   - livePayload: Bounded live projection read payload.
    ///   - currentStateFound: Whether the Current State context exists.
    ///   - currentStateSessions: Bounded active session facts from Current State.
    /// - Returns: A diagnostic result containing mismatch rows only.
    public static func compare(
        sessionID: String,
        livePayload: ExecutionTelemetryLiveProjectionReadPayload,
        currentStateFound: Bool,
        currentStateSessions: [ExecutionTelemetryObservationCurrentStateSession]
    ) -> ExecutionTelemetryObservationDiagnostic {
        let snapshot = livePayload.snapshot
        let currentSession = matchedSession(
            sessionID: sessionID,
            snapshot: snapshot,
            currentStateSessions: currentStateSessions
        )
        var mismatches: [ExecutionTelemetryObservationMismatch] = []

        if snapshot == nil, currentSession != nil {
            mismatches.append(ExecutionTelemetryObservationMismatch(
                code: "live_snapshot_missing",
                live: "missing",
                currentState: "present"
            ))
        }

        if snapshot != nil, !currentStateFound {
            mismatches.append(ExecutionTelemetryObservationMismatch(
                code: "current_state_context_missing",
                live: "present",
                currentState: "missing"
            ))
        } else if snapshot != nil, currentSession == nil {
            mismatches.append(ExecutionTelemetryObservationMismatch(
                code: "current_state_session_missing",
                live: "present",
                currentState: "missing"
            ))
        }

        if let snapshot, let currentSession {
            if snapshot.provider.lowercased() != currentSession.provider.lowercased() {
                mismatches.append(ExecutionTelemetryObservationMismatch(
                    code: "provider_identity_mismatch",
                    live: snapshot.provider,
                    currentState: currentSession.provider
                ))
            }
            let currentStatus = currentSession.lifecycleStatus.lowercased()
            if snapshot.lifecycleState == .running, currentStatus != "active" {
                mismatches.append(ExecutionTelemetryObservationMismatch(
                    code: "lifecycle_presence_mismatch",
                    live: snapshot.lifecycleState.rawValue,
                    currentState: currentSession.lifecycleStatus
                ))
            }
        }

        return ExecutionTelemetryObservationDiagnostic(sessionID: sessionID, mismatches: mismatches)
    }

    private static func matchedSession(
        sessionID: String,
        snapshot: ExecutionTelemetryLiveProjectionSnapshot?,
        currentStateSessions: [ExecutionTelemetryObservationCurrentStateSession]
    ) -> ExecutionTelemetryObservationCurrentStateSession? {
        let candidateIDs = [
            sessionID,
            snapshot?.sessionID,
            snapshot?.providerSessionID,
        ].compactMap { value -> String? in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }
        return currentStateSessions.first { session in
            candidateIDs.contains(session.sessionID)
        }
    }
}
