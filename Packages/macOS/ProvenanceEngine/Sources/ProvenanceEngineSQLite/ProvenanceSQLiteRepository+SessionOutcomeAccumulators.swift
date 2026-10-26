import Foundation
import ProvenanceEngineContracts

struct SessionOutcomePlanAccumulator {
    let firstText: String
    let firstTurnID: String
    private var latestText: String
    private var latestStatus: String
    private var latestTurnID: String
    private var latestRevisionID: String
    private var sourcePlanItemIDs: [String]
    private var latestEvidence: [ProvenanceTurnOutcomeEvidenceReference]

    init(firstText: String, firstTurnID: String) {
        self.firstText = firstText
        self.firstTurnID = firstTurnID
        self.latestText = firstText
        self.latestStatus = "unknown"
        self.latestTurnID = firstTurnID
        self.latestRevisionID = ""
        self.sourcePlanItemIDs = []
        self.latestEvidence = []
    }

    mutating func append(_ item: ProvenanceTurnOutcomePlanItem, from outcome: ProvenanceTurnOutcome) {
        latestText = item.text
        latestStatus = item.status
        latestTurnID = outcome.turnID
        latestRevisionID = outcome.projection.revisionID
        let scopedID = "\(outcome.turnID):\(item.id)"
        if !sourcePlanItemIDs.contains(scopedID) {
            sourcePlanItemIDs.append(scopedID)
        }
        latestEvidence = item.evidence
    }

    func planItem(id: String) -> ProvenanceSessionOutcomePlanItem {
        ProvenanceSessionOutcomePlanItem(
            id: id,
            text: latestText,
            status: latestStatus,
            firstObservedTurnID: firstTurnID,
            latestObservedTurnID: latestTurnID,
            latestTurnOutcomeRevisionID: latestRevisionID,
            sourcePlanItemIDs: sourcePlanItemIDs,
            evidence: latestEvidence
        )
    }
}

struct SessionOutcomeBoundaryKey: Hashable {
    let repositoryID: String?
    let repositoryPath: String?
    let worktreeID: String?
    let worktreePath: String?
    let branch: String?
    let head: String?
    let cwd: String?

    init(boundary: ProvenanceTurnOutcomeRepositoryBoundary) {
        self.repositoryID = boundary.repositoryID
        self.repositoryPath = boundary.repositoryPath
        self.worktreeID = boundary.worktreeID
        self.worktreePath = boundary.worktreePath
        self.branch = boundary.branch
        self.head = boundary.head
        self.cwd = boundary.cwd
    }

    var fingerprintValue: String {
        [
            repositoryID ?? "",
            repositoryPath ?? "",
            worktreeID ?? "",
            worktreePath ?? "",
            branch ?? "",
            head ?? "",
            cwd ?? "",
        ].joined(separator: "\n")
    }
}

struct SessionOutcomeBoundaryAccumulator {
    let key: SessionOutcomeBoundaryKey
    private var turnIDs: [String]
    private var revisionIDs: [String]
    private var evidence: [ProvenanceTurnOutcomeEvidenceReference]

    init(boundary: ProvenanceTurnOutcomeRepositoryBoundary) {
        self.key = SessionOutcomeBoundaryKey(boundary: boundary)
        self.turnIDs = []
        self.revisionIDs = []
        self.evidence = []
    }

    mutating func append(_ boundary: ProvenanceTurnOutcomeRepositoryBoundary, from outcome: ProvenanceTurnOutcome) {
        if !turnIDs.contains(outcome.turnID) {
            turnIDs.append(outcome.turnID)
        }
        let revisionID = outcome.projection.revisionID
        if !revisionIDs.contains(revisionID) {
            revisionIDs.append(revisionID)
        }
        evidence = Self.deduplicated(evidence + boundary.evidence)
    }

    func boundaryFact(id: String) -> ProvenanceSessionOutcomeRepositoryBoundary {
        ProvenanceSessionOutcomeRepositoryBoundary(
            id: id,
            repositoryID: key.repositoryID,
            repositoryPath: key.repositoryPath,
            worktreeID: key.worktreeID,
            worktreePath: key.worktreePath,
            branch: key.branch,
            head: key.head,
            cwd: key.cwd,
            turnIDs: turnIDs,
            turnOutcomeRevisionIDs: revisionIDs,
            evidence: evidence
        )
    }

    private static func deduplicated(
        _ references: [ProvenanceTurnOutcomeEvidenceReference]
    ) -> [ProvenanceTurnOutcomeEvidenceReference] {
        var seen = Set<String>()
        var result: [ProvenanceTurnOutcomeEvidenceReference] = []
        for reference in references {
            let key = [
                reference.eventID,
                String(reference.eventSequence),
                reference.recordKind,
                reference.recordID,
                reference.interpretedByRuleVersion,
            ].joined(separator: "\u{0}")
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(reference)
        }
        return result
    }
}
