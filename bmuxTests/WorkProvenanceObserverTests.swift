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
struct WorkProvenanceObserverTests {
    @Test
    func observeDirtyWorkspacePersistsUnattributedFileProvenanceAndDedupesUnchangedState() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-observed-repo"
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "/tmp/bmux-observed-repo/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "feature/provenance",
            headCommit: "0123456789012345678901234567890123456789",
            isDirty: true,
            statusEntries: [
                WorkProvenanceGitStatusEntry(path: "Sources/App.swift", status: "modified"),
                WorkProvenanceGitStatusEntry(path: "Sources/NewFile.swift", status: "untracked")
            ]
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            dateProvider: { Date(timeIntervalSince1970: 300) }
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            stableWorkspaceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Provenance",
            currentDirectory: repositoryRoot
        )

        await service.observeWorkspaceSnapshot(workspace)
        await service.observeWorkspaceSnapshot(workspace)

        let worktrees = try await client.worktrees(ProvenanceWorktreeListRequest())
        let context = try await client.currentContext(ProvenanceCurrentContextRequest(repositoryPath: repositoryRoot))
        let modified = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/App.swift"
        })
        let untracked = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/NewFile.swift"
        })

        #expect(worktrees.worktrees.count == 1)
        #expect(worktrees.worktrees.first?.repository?.remoteSlug == "manaflow-ai/bmux")
        #expect(context.worktree?.branch == "feature/provenance")
        #expect(context.worktree?.isDirty == true)
        #expect(modified.fileChange.status == "modified")
        #expect(modified.fileChange.attributionSource == .unattributed)
        #expect(modified.fileChange.attributionConfidence == .low)
        #expect(untracked.fileChange.status == "untracked")
    }

    @Test
    func nonRepositoryWorkspaceDoesNotAppendAnEvent() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [:])
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            stableWorkspaceID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "No Repo",
            currentDirectory: "/tmp/not-a-repo"
        )

        await service.observeWorkspaceSnapshot(workspace)

        let context = try await client.currentContext(ProvenanceCurrentContextRequest(repositoryPath: "/tmp/not-a-repo"))
        #expect(context.found == false)
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }

    private struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-work-provenance-observation-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }
}
