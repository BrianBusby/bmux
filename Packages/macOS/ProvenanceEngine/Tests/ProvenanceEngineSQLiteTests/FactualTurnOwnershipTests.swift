import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct FactualTurnOwnershipTests {
    private func reassociate<T: Codable>(_ value: T, sessionID: String, removeTurn: Bool = false) throws -> T {
        let encoded = try JSONEncoder().encode(value)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["sessionID"] = sessionID
        if removeTurn { json["turnID"] = NSNull() }
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test
    func turnFactsRequireMatchingSessionBeforeAndAfterReplay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pe-factual-ownership-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: directory.appendingPathComponent("provenance.sqlite"))
        let fixture = WorkModelFixture()
        let turn = fixture.turn(status: "started")
        try await fixture.appendSessionThreadAndTurn(turn, into: repository)
        let prompt = fixture.prompt("Valid prompt", turnID: turn.id, offset: 3)
        let plan = fixture.plan("Valid plan", turnID: turn.id, offset: 4)
        let command = fixture.command("valid command", turnID: turn.id, offset: 5)
        let reasoning = fixture.reasoning("Completed: valid reasoning", turnID: turn.id, offset: 6)
        let message = fixture.assistantMessage("valid message", turnID: turn.id, offset: 7)
        let change = fixture.fileAttribution("valid change", turnID: turn.id, offset: 8)
        try await fixture.append(prompt, into: repository)
        try await fixture.append(plan, into: repository)
        try await fixture.append(command, into: repository)
        try await fixture.append(reasoning, into: repository)
        try await fixture.append(message, into: repository)
        try await fixture.append(change, into: repository)
        let foreign = "unrelated-session"
        let foreignPrompt = try reassociate(fixture.prompt("Foreign prompt", turnID: turn.id, offset: 13), sessionID: foreign)
        let foreignPlan = try reassociate(fixture.plan("Foreign plan", turnID: turn.id, offset: 14), sessionID: foreign)
        let foreignCommand = try reassociate(fixture.command("foreign command", turnID: turn.id, offset: 15), sessionID: foreign)
        let foreignReasoning = try reassociate(fixture.reasoning("Completed: foreign reasoning", turnID: turn.id, offset: 16), sessionID: foreign)
        let foreignMessage = try reassociate(fixture.assistantMessage("foreign message", turnID: turn.id, offset: 17), sessionID: foreign)
        let foreignChange = try reassociate(fixture.fileAttribution("foreign change", turnID: turn.id, offset: 18), sessionID: foreign)
        let unassociated = try reassociate(fixture.prompt("Unassociated prompt", turnID: turn.id, offset: 19), sessionID: fixture.session.id, removeTurn: true)
        try await fixture.append(foreignPrompt, into: repository)
        try await fixture.append(foreignPlan, into: repository)
        try await fixture.append(foreignCommand, into: repository)
        try await fixture.append(foreignReasoning, into: repository)
        try await fixture.append(foreignMessage, into: repository)
        try await fixture.append(foreignChange, into: repository)
        try await fixture.append(unassociated, into: repository)

        for replay in [false, true] {
            if replay { _ = try await repository.rebuildProjectionsFromEventLedger(batchSize: 3) }
            let snapshot = try #require(await repository.factualSessionProjection(
                ProvenanceFactualSessionProjectionRequest(sessionID: fixture.session.id)).snapshot)
            let current = try #require(snapshot.latestTurn)
            #expect(current.submittedPrompt == prompt)
            #expect(current.currentPlan == plan)
            #expect(current.completedCommands == [command])
            #expect(current.visibleReasoningSummaries == [reasoning])
            #expect(current.assistantMessages == [message])
            #expect(current.fileChangeAttributions == [change])
            let detail = try await repository.factualSessionTurnDetail(ProvenanceFactualSessionTurnDetailRequest(turnID: turn.id))
            #expect(detail.turnDetail == current)
            let model = try #require(await repository.sessionWorkModel(ProvenanceSessionWorkModelRequest(sessionID: fixture.session.id)).model)
            #expect(model.currentTurn?.prompt == prompt)
            #expect(model.currentTurn?.plan == plan)
            #expect(model.currentTurn?.completedCommands == [command])
            let outcome = try #require(await repository.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: turn.id)).outcome)
            #expect(outcome.objective?.text == prompt.text)
            #expect(outcome.planItems.map(\.text) == ["Valid plan"])
            #expect(outcome.commandsCompleted.map(\.id) == [command.id])
            #expect(!outcome.actionsCompleted.contains { $0.text.contains("foreign") })
            #expect(outcome.artifactsChanged.allSatisfy { $0.id.contains(change.id) })
            let session = try #require(await repository.sessionOutcome(ProvenanceSessionOutcomeRequest(sessionID: fixture.session.id)).outcome)
            #expect(session.turnOutcomes.first?.objective?.text == prompt.text)
            #expect(session.commandsCompleted.map(\.command.id) == [command.id])
            #expect(try await repository.codingAgentPrompt(id: foreignPrompt.id) == foreignPrompt)
            #expect(try await repository.codingAgentPlanUpdate(id: foreignPlan.id) == foreignPlan)
            #expect(try await repository.codingAgentCommand(id: foreignCommand.id) == foreignCommand)
            #expect(try await repository.codingAgentReasoningSummary(id: foreignReasoning.id) == foreignReasoning)
            #expect(try await repository.codingAgentAssistantMessage(id: foreignMessage.id) == foreignMessage)
            #expect(try await repository.codingAgentFileChangeAttribution(id: foreignChange.id) == foreignChange)
            #expect(try await repository.codingAgentPrompt(id: unassociated.id) == unassociated)
        }
    }
}
