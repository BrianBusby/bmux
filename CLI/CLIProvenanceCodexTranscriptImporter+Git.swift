import Foundation
import ProvenanceEngineContracts

extension CLIProvenanceCodexTranscriptImporter {
    func gitContext(for directory: String?, observedAt: Date) async -> GitContext? {
        guard let directory = Self.trimmedNonEmpty(directory),
              let snapshot = Self.gitSnapshot(for: directory) else {
            return nil
        }
        let repositoryID = stableIDFactory.repositoryID(repositoryRoot: snapshot.repositoryRoot)
        let worktreeID = stableIDFactory.worktreeID(repositoryRoot: snapshot.repositoryRoot)
        return GitContext(
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            repository: ProvenanceRepositoryRecord(
                id: repositoryID,
                path: snapshot.repositoryRoot,
                commonDirectory: snapshot.commonDirectory,
                remoteSlug: snapshot.remoteSlug,
                createdAt: observedAt,
                updatedAt: observedAt
            ),
            worktree: ProvenanceWorktreeRecord(
                id: worktreeID,
                repositoryID: repositoryID,
                path: snapshot.repositoryRoot,
                branch: snapshot.branch,
                currentHEAD: snapshot.headCommit,
                isDirty: snapshot.isDirty,
                status: "active",
                lastReconciledAt: observedAt,
                updatedAt: observedAt
            )
        )
    }

    private static func gitSnapshot(for directory: String) -> GitSnapshot? {
        guard let root = gitText(["-C", directory, "rev-parse", "--show-toplevel"]) else {
            return nil
        }
        let commonDirectory = gitText(["-C", root, "rev-parse", "--git-common-dir"]).map {
            absolutePath($0, relativeTo: root)
        }
        let branch = gitText(["-C", root, "branch", "--show-current"])
        let headCommit = gitText(["-C", root, "rev-parse", "--verify", "HEAD"])
        let status = gitText(["-C", root, "status", "--porcelain=v1", "--untracked-files=all"])
        let remoteSlug = gitText(["-C", root, "config", "--get", "remote.origin.url"]).flatMap(remoteSlug)
        return GitSnapshot(
            repositoryRoot: root,
            commonDirectory: commonDirectory,
            remoteSlug: remoteSlug,
            branch: branch,
            headCommit: headCommit,
            isDirty: status?.isEmpty == false
        )
    }

    private static func gitText(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: outputData, encoding: .utf8) else {
            return nil
        }
        return trimmedNonEmpty(text)
    }

    private static func absolutePath(_ path: String, relativeTo root: String) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        return URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(path)
            .standardizedFileURL
            .path
    }

    private static func remoteSlug(_ remoteURL: String) -> String? {
        let trimmed = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withoutSuffix = trimmed.hasSuffix(".git") ? String(trimmed.dropLast(4)) : trimmed
        if let range = withoutSuffix.range(of: "github.com[:/]", options: .regularExpression) {
            return String(withoutSuffix[range.upperBound...])
        }
        return nil
    }
}
