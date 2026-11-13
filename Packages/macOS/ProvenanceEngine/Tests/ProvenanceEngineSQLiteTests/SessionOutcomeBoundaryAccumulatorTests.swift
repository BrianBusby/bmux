import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct SessionOutcomeBoundaryAccumulatorTests {
    @Test
    func boundaryAccumulatorRetainsFirstEvidenceInEncounterOrder() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = TurnOutcomeFixture(suffix: "boundary-evidence-order")
        for event in fixture.normalEvents { try await repository.appendEvent(event) }
        let outcome = try #require(try await repository.turnOutcome(
            ProvenanceTurnOutcomeRequest(turnID: fixture.turnCompleted.id)
        ).outcome)
        let original = try #require(outcome.repositoryBoundary)
        func reference(_ id: String, state: String) -> ProvenanceTurnOutcomeEvidenceReference {
            ProvenanceTurnOutcomeEvidenceReference(
                eventID: id, eventSequence: 1, eventType: "test", source: .observed,
                evidenceOrigin: nil, evidenceScope: nil, recordKind: "repository", recordID: "repo",
                interpretedByRuleVersion: "1", sourceState: state
            )
        }
        let first = reference("a", state: "available")
        let duplicate = reference("a", state: "historical")
        let second = reference("b", state: "available")
        func boundary(_ evidence: [ProvenanceTurnOutcomeEvidenceReference]) -> ProvenanceTurnOutcomeRepositoryBoundary {
            ProvenanceTurnOutcomeRepositoryBoundary(
                repositoryID: original.repositoryID, repositoryPath: original.repositoryPath,
                worktreeID: original.worktreeID, worktreePath: original.worktreePath,
                branch: original.branch, head: original.head, cwd: original.cwd, evidence: evidence
            )
        }
        var accumulator = SessionOutcomeBoundaryAccumulator(boundary: original)
        accumulator.append(boundary([first, second, duplicate]), from: outcome)
        accumulator.append(boundary([duplicate, first]), from: outcome)
        let result = accumulator.boundaryFact(id: "boundary")
        #expect(result.evidence == [first, second])
        #expect(result.turnIDs == [outcome.turnID])
        #expect(result.turnOutcomeRevisionIDs == [outcome.projection.revisionID])
    }

}
