import BmuxGit
import Foundation

/// Production Git inspector for observe-only provenance collection.
struct WorkProvenanceGitInspector: WorkProvenanceGitInspecting {
    private let commandRunner: any WorkProvenanceGitCommandRunning
    private let metadataService: GitMetadataService

    /// Creates a Git inspector.
    init(
        commandRunner: any WorkProvenanceGitCommandRunning = WorkProvenanceProcessGitCommandRunner(),
        metadataService: GitMetadataService = GitMetadataService()
    ) {
        self.commandRunner = commandRunner
        self.metadataService = metadataService
    }

    func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
        let normalizedDirectory = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDirectory.isEmpty,
              let root = await gitText(["-C", normalizedDirectory, "rev-parse", "--show-toplevel"],
                                       workingDirectory: normalizedDirectory) else {
            return nil
        }

        let metadata = await metadataService.workspaceMetadata(for: root)
        guard metadata.isRepository else { return nil }

        let commonDirectory = await gitText(["-C", root, "rev-parse", "--git-common-dir"], workingDirectory: root)
            .map { Self.absolutePath($0, relativeTo: root) }
        let branch = await gitText(["-C", root, "branch", "--show-current"], workingDirectory: root)
            ?? metadata.branch
        let headCommit = await gitText(["-C", root, "rev-parse", "--verify", "HEAD"], workingDirectory: root)
        let statusData = await gitData(
            ["-C", root, "status", "--porcelain=v1", "-z", "--untracked-files=all"],
            workingDirectory: root
        ) ?? Data()
        let statusEntries = Self.statusEntries(from: statusData)
        let remoteSlug = await metadataService.repositorySlugs(forDirectory: root).first

        return WorkProvenanceGitSnapshot(
            repositoryRoot: root,
            commonDirectory: commonDirectory,
            remoteSlug: remoteSlug,
            branch: branch,
            headCommit: headCommit,
            isDirty: metadata.isDirty || !statusEntries.isEmpty,
            statusEntries: statusEntries
        )
    }

    private func gitText(_ arguments: [String], workingDirectory: String) async -> String? {
        guard let data = await gitData(arguments, workingDirectory: workingDirectory),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func gitData(_ arguments: [String], workingDirectory: String) async -> Data? {
        do {
            let result = try await commandRunner.runGit(
                arguments: arguments,
                workingDirectory: workingDirectory
            )
            guard result.exitCode == 0 else {
                let stderr = String(data: result.standardError, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                NSLog("bmux provenance git command failed: git %@ cwd=%@ exit=%d stderr=%@", arguments.joined(separator: " "), workingDirectory, result.exitCode, stderr)
                return nil
            }
            return result.standardOutput
        } catch {
            NSLog("bmux provenance git command could not run: git %@ cwd=%@ error=%@", arguments.joined(separator: " "), workingDirectory, String(describing: error))
            return nil
        }
    }

    static func statusEntries(from data: Data) -> [WorkProvenanceGitStatusEntry] {
        let chunks = data.split(separator: 0, omittingEmptySubsequences: true)
        var entries: [WorkProvenanceGitStatusEntry] = []
        var index = 0
        while index < chunks.count {
            let item = String(decoding: chunks[index], as: UTF8.self)
            index += 1
            guard item.count >= 4 else { continue }

            let statusCode = String(item.prefix(2))
            let pathStart = item.index(item.startIndex, offsetBy: 3)
            let path = String(item[pathStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }

            var previousPath: String?
            if statusCode.contains("R") || statusCode.contains("C") {
                if index < chunks.count {
                    let previous = String(decoding: chunks[index], as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    previousPath = previous.isEmpty ? nil : previous
                    index += 1
                }
            }

            entries.append(
                WorkProvenanceGitStatusEntry(
                    path: path,
                    status: normalizedStatus(from: statusCode),
                    previousPath: previousPath
                )
            )
        }
        return entries.sorted { lhs, rhs in
            if lhs.path == rhs.path { return lhs.status < rhs.status }
            return lhs.path < rhs.path
        }
    }

    private static func normalizedStatus(from statusCode: String) -> String {
        if statusCode.contains("?") { return "untracked" }
        if statusCode.contains("R") { return "renamed" }
        if statusCode.contains("C") { return "copied" }
        if statusCode.contains("U") { return "unmerged" }
        if statusCode.contains("D") { return "deleted" }
        if statusCode.contains("A") { return "added" }
        return "modified"
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
}
