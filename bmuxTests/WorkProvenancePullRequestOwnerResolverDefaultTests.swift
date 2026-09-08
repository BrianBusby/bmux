import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkProvenancePullRequestOwnerResolverDefaultTests {
    @Test
    func defaultObservationServiceKeepsPullRequestFactsWithoutOwnerLookup() async throws {
        let databaseDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "bmux-work-provenance-default-pr-owner-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: databaseDir) }
        try FileManager.default.createDirectory(at: databaseDir, withIntermediateDirectories: true)
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: databaseDir.appendingPathComponent("provenance.sqlite")
        )
        let repositoryRoot = "/tmp/bmux-default-pr-owner-resolver-repo"
        let branch = "feature/runtime-owned-pr-metadata"
        let stableWorkspaceID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(gitSnapshot: WorkProvenanceGitSnapshot(
                repositoryRoot: repositoryRoot,
                commonDirectory: "\(repositoryRoot)/.git",
                remoteSlug: "manaflow-ai/bmux",
                branch: branch,
                headCommit: "1212121212121212121212121212121212121212",
                isDirty: false,
                statusEntries: []
            )),
            dateProvider: { Date(timeIntervalSince1970: 575) }
        )

        await service.observeWorkspaceSnapshot(WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Runtime-owned PR metadata",
            currentDirectory: repositoryRoot,
            branch: branch,
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 5314,
                url: "https://github.com/manaflow-ai/bmux/pull/5314",
                ownerLogin: nil,
                ownerURL: nil,
                status: "open",
                branch: nil,
                isStale: false
            )
        ))

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))
        #expect(display.found)
        #expect(display.display?.pullRequestNumber == 5314)
        #expect(display.display?.pullRequestOwnerLogin == nil)
        #expect(display.display?.pullRequestOwnerURL == nil)
        #expect(display.display?.pullRequestBranch == nil)
        #expect(display.display?.ticketIDs == [])
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let gitSnapshot: WorkProvenanceGitSnapshot

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            gitSnapshot
        }
    }
}
