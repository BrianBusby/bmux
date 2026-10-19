import Testing

struct CodexMonitorLeaseTests {
    @Test(arguments: [true, false])
    func nextPromptRespectsPriorTurnCompletion(completedPriorTurn: Bool) async throws {
        let fixture = try CodexMonitorLeaseFixture()
        let snapshots = try await fixture.run(completedPriorTurn: completedPriorTurn)
        #expect(snapshots.first.active.count == 1)
        let first = try #require(snapshots.first.active.first)
        #expect(first.turnId == "turn-one")
        #expect(snapshots.first.depth == 1)
        #expect(snapshots.first.turns == ["turn-one"])
        #expect(snapshots.second.active.count == 1)
        let current = try #require(snapshots.second.active.first)
        for lease in [first, current] {
            #expect(lease.sessionId == fixture.session)
            #expect(lease.workspaceId == fixture.workspace)
            #expect(lease.surfaceId == fixture.surface)
        }
        if completedPriorTurn {
            #expect(current.turnId == "turn-two")
            #expect(current.leaseId != first.leaseId)
            #expect(snapshots.second.depth == 1)
            #expect(snapshots.second.turns == ["turn-two"])
            // Removal is normal retirement completion; a retained prior record must be marked retired.
            if let retired = snapshots.second.leases.first(where: { $0.leaseId == first.leaseId }) {
                #expect(retired.retiredAt != nil)
            }
        } else {
            #expect(current.turnId == "turn-one")
            #expect(current.leaseId == first.leaseId)
            #expect(current.retiredAt == nil)
            #expect(snapshots.second.depth == 2)
            #expect(snapshots.second.turns == ["turn-one", "turn-two"])
        }
    }
}
