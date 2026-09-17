import Foundation
import Testing
@testable import BmuxAgentChat

@Suite struct CodexSharedControlTests {
    @Test func acceptanceAndDuplicateRequestsStayWithTheirOwner() async throws {
        let transport = ScriptedCodexTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let control = CodexSharedControl(threadID: "thread-a", connection: connection)
        let action = CodexControlAction(id: UUID(), threadID: "thread-a", operation: .queue, text: "Inspect the build")
        let result = try await control.submit(action)
        #expect(result.delivery == .accepted)
        #expect(result.providerID == "queued-1")
        await #expect(throws: CodexControlError.duplicateRequest) { try await control.submit(action) }
        await #expect(throws: CodexControlError.wrongThread) {
            try await control.submit(CodexControlAction(id: UUID(), threadID: "thread-b", operation: .queue, text: "Other workspace"))
        }
        #expect(await transport.mutations == 1)
        await connection.disconnect()
    }

    @Test func lostAcknowledgmentRemainsUncertainAndIsNeverRetried() async throws {
        let transport = ScriptedCodexTransport(loseAcknowledgment: true)
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let control = CodexSharedControl(threadID: "thread-a", connection: connection)
        let action = CodexControlAction(id: UUID(), threadID: "thread-a", operation: .queue, text: "Inspect the build")
        #expect(try await control.submit(action).delivery == .uncertain)
        await #expect(throws: CodexControlError.duplicateRequest) { try await control.submit(action) }
        #expect(await transport.mutations == 1)
        #expect(await control.actionSnapshot().first?.text == action.text)
        await connection.disconnect()
    }

    @Test func steeringCarriesExpectedTurnAndRejectionPreservesDraft() async throws {
        let transport = ScriptedCodexTransport(rejectSteer: true)
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let control = CodexSharedControl(threadID: "thread-a", connection: connection)
        let action = CodexControlAction(id: UUID(), threadID: "thread-a", operation: .steer, expectedTurnID: "old-turn", text: "Focus on tests")
        let result = try await control.submit(action)
        #expect(result.delivery == .failed)
        #expect(result.text == action.text)
        #expect(await transport.expectedTurnID == "old-turn")
        await connection.disconnect()
    }

    @Test func reconnectReconcilesAcceptanceWithoutReplayingTheMutation() async throws {
        let transport = ScriptedCodexTransport(loseAcknowledgment: true)
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let control = CodexSharedControl(threadID: "thread-a", connection: connection)
        let action = CodexControlAction(id: UUID(), threadID: "thread-a", operation: .queue, text: "Inspect the build")
        #expect(try await control.submit(action).delivery == .uncertain)
        let replacementTransport = ScriptedCodexTransport(acceptedClientID: action.id.uuidString)
        let replacement = CodexRPCConnection(transport: replacementTransport)
        try await replacement.start()
        await control.reconnect(using: replacement)
        try await control.reconcile()
        #expect(await control.actionSnapshot().first?.delivery == .accepted)
        #expect(await replacementTransport.mutations == 0)
        await #expect(throws: CodexControlError.duplicateRequest) { try await control.submit(action) }
        await replacement.disconnect()
    }

    @Test func slashCommandsAreNotSilentlyConvertedToPrompts() async throws {
        let transport = ScriptedCodexTransport()
        let connection = CodexRPCConnection(transport: transport)
        try await connection.start()
        let control = CodexSharedControl(threadID: "thread-a", connection: connection)
        await #expect(throws: CodexControlError.invalidInput) {
            try await control.submit(CodexControlAction(id: UUID(), threadID: "thread-a", operation: .queue, text: "/model"))
        }
        #expect(await transport.mutations == 0)
        await connection.disconnect()
    }
}
