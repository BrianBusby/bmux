import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct SessionLifecycleIdentityTests {
    @Test(arguments: [false, true])
    func rejectsUnidentifiedTransitionsWithoutChangingHistoricalSession(child: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let factory = ProvenanceStableIDFactory()
        let parent = child ? "parent" : nil
        let legacyIdentity = child ? "codex:parent:default" : "codex:default"
        let legacyID = if let parent {
            factory.subsessionSessionID(agentKind: "codex", parentSessionID: parent,
                                        identityKind: "unresolved_session", identityValue: legacyIdentity)
        } else {
            factory.sessionID(agentKind: "codex", identityKind: "unresolved_session", identityValue: legacyIdentity)
        }
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let historical = ProvenanceSessionRecord(id: legacyID, agentKind: "codex", status: "active",
                                                 startedAt: time, updatedAt: time)
        try await repository.appendEvent(ProvenanceEvent(
            id: "historical", eventType: .sessionStarted, timestamp: time, sessionID: legacyID,
            source: .observed, confidence: .low, payload: ProvenanceEventPayload(session: historical)
        ))
        for (offset, phase) in [ProvenanceSessionLifecyclePhase.started, .started, .stopped].enumerated() {
            let response = await repository.recordSessionLifecycle(ProvenanceSessionLifecycleRequest(
                phase: phase, sessionID: offset == 1 ? "  " : nil, parentSessionID: parent,
                agentKind: "codex", workspaceID: "workspace-\(offset)",
                externalIdentityValue: offset == 1 ? " \n " : nil,
                timestamp: time.addingTimeInterval(Double(offset + 1))
            ))
            #expect(!response.accepted)
            #expect(response.sessionID == nil)
            #expect(response.eventID == nil)
            #expect(response.errorDescription != nil)
        }
        let reopened = try ProvenanceSQLiteRepository(url: url)
        #expect(try await reopened.session(id: legacyID) == historical)
    }
    @Test
    func identifiedRootAndChildRemainAcceptedAcrossRestart() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = try ProvenanceSQLiteRepository(url: url)
        let root = await repository.recordSessionLifecycle(.init(
            phase: .started, sessionID: "root", agentKind: "codex", timestamp: time
        ))
        let child = await repository.recordSessionLifecycle(.init(
            phase: .started, parentSessionID: "root", agentKind: "codex",
            externalIdentityKind: "child", externalIdentityValue: "child-1", timestamp: time
        ))
        #expect(root.accepted)
        #expect(child.accepted)
        let childID = try #require(child.sessionID)
        let reopened = try ProvenanceSQLiteRepository(url: url)
        let stop = await reopened.recordSessionLifecycle(.init(
            phase: .stopped, parentSessionID: "root", agentKind: "codex",
            externalIdentityKind: "child", externalIdentityValue: "child-1", timestamp: time.addingTimeInterval(1)
        ))
        #expect(stop.accepted)
        #expect(stop.sessionID == childID)
        #expect(try await reopened.session(id: "root")?.status == "active")
        #expect(try await reopened.session(id: childID)?.status == "completed")
    }

}
