import Foundation
import ProvenanceEngineContracts
import Testing

@Suite
struct ProvenanceEngineHealthTests {
    @Test
    func healthPayloadRoundTripsThroughJSON() throws {
        let health = ProvenanceEngineHealth(
            status: .available,
            version: "0.1.0",
            capabilities: [
                .appendEvent,
                .querySessionTree,
                .queryCurrentContext,
            ]
        )

        let data = try JSONEncoder().encode(health)
        let decoded = try JSONDecoder().decode(ProvenanceEngineHealth.self, from: data)

        #expect(decoded == health)
        #expect(decoded.schemaVersion == 1)
    }

    @Test
    func capabilityRawValuesAreStableSnakeCaseNames() {
        #expect(ProvenanceEngineCapability.appendEvent.rawValue == "append_event")
        #expect(ProvenanceEngineCapability.recordSubsessionLifecycle.rawValue == "record_subsession_lifecycle")
        #expect(ProvenanceEngineCapability.querySessionTree.rawValue == "query_session_tree")
        #expect(ProvenanceEngineCapability.queryFileExplanation.rawValue == "query_file_explanation")
        #expect(ProvenanceEngineCapability.queryWorktrees.rawValue == "query_worktrees")
        #expect(ProvenanceEngineCapability.queryCurrentContext.rawValue == "query_current_context")
    }

    @Test
    func healthCheckingProtocolSupportsInProcessClients() async throws {
        let client = StaticHealthClient(
            health: ProvenanceEngineHealth(
                status: .degraded,
                version: "0.1.0",
                capabilities: [.queryWorktrees]
            )
        )

        let health = try await client.health()

        #expect(health.status == .degraded)
        #expect(health.capabilities == [.queryWorktrees])
    }
}

private struct StaticHealthClient: ProvenanceEngineHealthChecking {
    let health: ProvenanceEngineHealth

    func health() async throws -> ProvenanceEngineHealth {
        health
    }
}
