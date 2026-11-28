import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Reads the factual session projection snapshot for one coding-agent session.
    ///
    /// - Parameter request: Factual session projection query parameters.
    /// - Returns: Found response with revisioned factual coding-agent evidence, or `no_session` when absent.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func factualSessionProjection(_ request: ProvenanceFactualSessionProjectionRequest) throws -> ProvenanceFactualSessionProjectionResponse {
        try database.withReadSnapshot { try readFactualSessionProjection(request) }
    }

    private func readFactualSessionProjection(_ request: ProvenanceFactualSessionProjectionRequest) throws -> ProvenanceFactualSessionProjectionResponse {
        guard let session = try session(id: request.sessionID) else {
            return ProvenanceFactualSessionProjectionResponse(
                found: false,
                reason: "no_session",
                sessionID: request.sessionID,
                snapshot: nil
            )
        }

#if DEBUG
        didReadFactualSessionForTesting?()
#endif
        let providerThreads = try codingAgentThreadIDs(sessionID: request.sessionID).compactMap {
            try codingAgentThread(id: $0)
        }
        let claims = try unresolvedTurnClaims(sessionID: request.sessionID)
        let unresolved = claims.ids
        let allTurnIDs = try codingAgentTurnIDs(sessionID: request.sessionID, limit: nil)
        var latestTurnID = allTurnIDs.last.flatMap { unresolved.contains($0) ? nil : $0 }
        let displaced = unresolved.subtracting(allTurnIDs)
        if let candidateID = latestTurnID, !displaced.isEmpty {
            let candidate = try codingAgentTurn(id: candidateID)
            let displacedTime = try displacedTurnSortTime(sessionID: request.sessionID, turnIDs: displaced)
            let candidateIsLater = candidate.flatMap { turn in
                displacedTime.map { (turn.startedAt ?? turn.updatedAt).timeIntervalSinceReferenceDate > $0 }
            } ?? false
            if !candidateIsLater { latestTurnID = nil }
        }
        let latestTurn = try latestTurnID.flatMap { try factualTurnSnapshot(turnID: $0) }
        let priorTurns = try allTurnIDs.dropLast(latestTurnID == nil ? 0 : 1).filter { !unresolved.contains($0) }.compactMap { turnID in
            try codingAgentTurn(id: turnID).map(ProvenanceFactualSessionProjectionTurnReference.init(turn:))
        }
        let turns = try codingAgentTurnIDs(
            sessionID: request.sessionID,
            limit: request.turnLimit
        ).filter { !unresolved.contains($0) }.compactMap { turnID in
            try factualTurnSnapshot(turnID: turnID)
        }

        let proposalRead = try recentProposedPlanObservations(sessionID: request.sessionID)
        let disputedProviderTurns = try disputedProviderTurnClaims(unresolved)
        let proposals = proposalRead.observations.filter { observation in
            guard let disputedProviderTurns, let providerTurnID = observation.proposal.providerTurnID else { return false }
            return !disputedProviderTurns.contains(.init(provider: observation.proposal.provider, providerTurnID: providerTurnID))
        }
        let proposalCoverage = ProvenanceProposedPlanReadCoverage(
            scanWindowTruncated: proposalRead.coverage.scanWindowTruncated,
            omittedObservations: proposalRead.coverage.omittedObservations || proposals.count != proposalRead.observations.count
        )
        return ProvenanceFactualSessionProjectionResponse(
            found: true,
            sessionID: request.sessionID,
            snapshot: ProvenanceFactualSessionProjectionSnapshot(
                revision: try [latestEventSequence(sessionID: request.sessionID), claims.watermark].compactMap { $0 }.max(),
                session: session,
                providerThreadIdentities: providerThreads.map(
                    ProvenanceFactualSessionProjectionProviderThreadIdentity.init(thread:)
                ),
                providerThreads: providerThreads,
                latestTurn: latestTurn,
                priorTurns: priorTurns,
                turns: turns,
                unresolvedTurnIDs: unresolved.sorted(),
                proposedPlanObservations: proposals,
                proposedPlanCoverage: proposalCoverage
            )
        )
    }

    /// Reads factual detail for one observed coding-agent turn.
    ///
    /// - Parameter request: Factual turn-detail query parameters.
    /// - Returns: Found response with revisioned factual turn evidence, or `no_turn` when absent.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read.
    func factualSessionTurnDetail(_ request: ProvenanceFactualSessionTurnDetailRequest) async throws
        -> ProvenanceFactualSessionTurnDetailResponse {
        try database.withReadSnapshot { try readFactualSessionTurnDetail(request) }
    }

    private func readFactualSessionTurnDetail(_ request: ProvenanceFactualSessionTurnDetailRequest) throws
        -> ProvenanceFactualSessionTurnDetailResponse {
        if try hasConflictingTurnClaims(request.turnID) {
            return ProvenanceFactualSessionTurnDetailResponse(
                found: false, reason: "ownership_unresolved", turnID: request.turnID, turnDetail: nil
            )
        }
        guard let detail = try factualTurnSnapshot(turnID: request.turnID) else {
            return ProvenanceFactualSessionTurnDetailResponse(
                found: false,
                reason: "no_turn",
                turnID: request.turnID,
                turnDetail: nil
            )
        }

        return ProvenanceFactualSessionTurnDetailResponse(
            found: true,
            turnID: request.turnID,
            sessionID: detail.turn.sessionID,
            revision: try latestEventSequence(sessionID: detail.turn.sessionID),
            turnDetail: detail
        )
    }

}
