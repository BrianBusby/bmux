import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

extension WorkspaceDisplayCurrentStateProjectionTests {
    @Test
    func newPullRequestDoesNotRetainPreviousOwnersAvatar() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_810_000_250)

        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-first-pr",
            timestamp: baseTime,
            display: Self.workspaceDisplay(
                pullRequestNumber: 41,
                pullRequestURL: "https://github.com/example/repo/pull/41",
                pullRequestOwnerAvatarURL: "https://avatars.githubusercontent.com/u/41?v=4",
                observedAt: baseTime
            ),
            into: repository
        )
        try await Self.appendWorkspaceDisplay(
            eventID: "event-workspace-display-next-pr",
            timestamp: baseTime.addingTimeInterval(1),
            display: Self.workspaceDisplay(
                pullRequestNumber: 42,
                pullRequestURL: "https://github.com/example/repo/pull/42",
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )

        let display = try #require(try await repository.workspaceDisplay(
            ProvenanceWorkspaceDisplayRequest(workspaceID: Self.workspaceID)
        ).display)
        #expect(display.pullRequestNumber == 42)
        #expect(display.pullRequestOwnerAvatarURL == nil)
    }

}
