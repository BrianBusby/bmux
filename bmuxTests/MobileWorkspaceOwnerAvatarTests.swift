import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct MobileWorkspaceOwnerAvatarTests {
    @MainActor @Test func ticketOwnerDoesNotUsePullRequestOwnerAvatar() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let client = try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: home)
        let workspace = Workspace(title: "Review roof inspection")
        let panelID = try #require(workspace.focusedPanelId)
        let pullRequestURL = try #require(URL(string: "https://github.com/example/repo/pull/42"))
        let avatarURL = try #require(URL(string: "https://avatars.githubusercontent.com/u/42?v=4"))
        workspace.updatePanelPullRequest(
            panelId: panelID, number: 42, label: "PR", url: pullRequestURL,
            ownerLogin: "octocat", ownerAvatarURL: avatarURL, status: .open
        )
        let now = Date()
        let display = ProvenanceWorkspaceDisplayRecord(
            id: "roof-work", workspaceID: workspace.stableId.uuidString,
            pullRequestNumber: 42, pullRequestURL: pullRequestURL.absoluteString,
            pullRequestOwnerLogin: "octocat", pullRequestOwnerAvatarURL: avatarURL.absoluteString,
            ticketLinks: [.init(id: "ROOF-42", ownerName: "Sam")],
            observedAt: now, updatedAt: now
        )
        _ = try await client.appendEvent(.init(event: .init(
            eventType: .workspaceDisplayObserved, timestamp: now,
            source: .observed, evidenceOrigin: .init(rawValue: "mobile-owner-avatar-test"),
            evidenceScope: .init(level: .personal, id: "mobile-owner-avatar-test"), confidence: .high,
            payload: .init(workspaceDisplay: display)
        )))
        let store = WorkspaceDisplayCurrentStateStore(client: client)
        _ = try #require(await store.refreshedSnapshot(stableWorkspaceID: workspace.stableId))
        let runtime = WorkProvenanceRuntime(observationService: nil, workspaceDisplayCurrentStateStore: store)
        let payload = TerminalController.shared.mobileWorkspacePayload(
            workspace: workspace, isSelected: true, requestedTerminalID: nil, workProvenanceRuntime: runtime
        )
        #expect(payload["owner_name"] as? String == "Sam")
        #expect(payload["owner_avatar_url"] is NSNull)
    }
}
