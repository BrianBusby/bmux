import Foundation

struct CLIProvenanceGitResolver {
    func resolve(
        path rawPath: String,
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        commandLabel: String = "provenance explain"
    ) throws -> CLIProvenanceResolvedTarget {
        let requestedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedPath.isEmpty else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(localized: "cli.provenance.error.commandRequiresPath", defaultValue: "%@ requires <path>"),
                commandLabel
            ))
        }

        let currentDirectoryURL = URL(fileURLWithPath: currentDirectory, isDirectory: true)
        let targetURL = requestedPath.hasPrefix("/")
            ? URL(fileURLWithPath: requestedPath).standardizedFileURL
            : URL(fileURLWithPath: requestedPath, relativeTo: currentDirectoryURL).standardizedFileURL
        let gitDirectory = gitProbeDirectory(for: targetURL, fallback: currentDirectoryURL)
        let repositoryRoot = try repositoryRoot(for: gitDirectory.path, commandLabel: commandLabel)
        guard let relativePath = relativePath(absolutePath: targetURL.path, repositoryRoot: repositoryRoot) else {
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.error.commandPathOutsideWorktree",
                    defaultValue: "%@ path is outside the current Git worktree: %@"
                ),
                commandLabel,
                targetURL.path
            ))
        }
        return CLIProvenanceResolvedTarget(
            requestedPath: requestedPath,
            absolutePath: targetURL.path,
            repositoryRoot: repositoryRoot,
            relativePath: relativePath
        )
    }

    private func gitProbeDirectory(for targetURL: URL, fallback: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue ? targetURL : targetURL.deletingLastPathComponent()
        }
        let parent = targetURL.deletingLastPathComponent()
        var parentIsDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory),
           parentIsDirectory.boolValue {
            return parent
        }
        return fallback
    }

    private func repositoryRoot(for directory: String, commandLabel: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory, "rev-parse", "--show-toplevel"]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0,
              let rawRoot = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawRoot.isEmpty else {
            let detail = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = detail?.isEmpty == false ? ": \(detail ?? "")" : ""
            throw CLIError(message: String.localizedStringWithFormat(
                String(
                    localized: "cli.provenance.error.commandRequiresGitWorktree",
                    defaultValue: "%@ requires a Git worktree%@"
                ),
                commandLabel,
                suffix
            ))
        }
        return URL(fileURLWithPath: rawRoot).standardizedFileURL.path
    }

    private func relativePath(absolutePath: String, repositoryRoot: String) -> String? {
        let root = URL(fileURLWithPath: repositoryRoot, isDirectory: true).standardizedFileURL.path
        let absolute = URL(fileURLWithPath: absolutePath).standardizedFileURL.path
        if absolute == root { return "." }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard absolute.hasPrefix(prefix) else { return nil }
        return String(absolute.dropFirst(prefix.count))
    }
}
