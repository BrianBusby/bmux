import BmuxFoundation
import CryptoKit
import Foundation

/// Acquires and atomically publishes a verified, private Codex package. Never updates a global CLI.
actor ManagedCodexRuntime {
    private let root: URL
    private let release: ManagedCodexRelease
    private let commands: any CommandRunning
    private let download: @Sendable (URL) async throws -> URL
    private var installation: Task<URL, Error>?

    init(root: URL, release: ManagedCodexRelease = .validated,
         commands: any CommandRunning = CommandRunner(environment: ["PATH": "/usr/bin:/bin"]),
         download: @escaping @Sendable (URL) async throws -> URL = { url in
             let configuration = URLSessionConfiguration.ephemeral
             configuration.timeoutIntervalForRequest = 30
             configuration.timeoutIntervalForResource = 180
             let session = URLSession(configuration: configuration)
             defer { session.finishTasksAndInvalidate() }
             let (file, response) = try await session.download(from: url)
             guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                 try? FileManager.default.removeItem(at: file)
                 throw ManagedCodexRuntimeError.downloadFailed
             }
             return file
         }) {
        self.root = root
        self.release = release
        self.commands = commands
        self.download = download
    }

    func executable() async throws -> URL {
        if let installation { return try await installation.value }
        // Concurrent launches share acquisition; closing one workspace must not cancel the others.
        let task = Task { try await acquire() }
        installation = task
        defer { installation = nil }
        return try await task.value
    }

    private func acquire() async throws -> URL {
        let destination = root.appendingPathComponent(release.directoryName, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            return try await validatedExecutable(in: destination)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let staging = root.appendingPathComponent(".install-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: staging) }
        let archive: URL
        do { archive = try await download(release.archiveURL) }
        catch { throw ManagedCodexRuntimeError.downloadFailed }
        defer { try? FileManager.default.removeItem(at: archive) }
        guard try digest(of: archive) == release.archiveSHA256 else {
            throw ManagedCodexRuntimeError.invalidPackage
        }
        let extracted = await commands.run(directory: staging.path, executable: "/usr/bin/tar",
            arguments: ["-xzf", archive.path, "-C", staging.path], timeout: 60)
        guard extracted.executionError == nil, !extracted.timedOut, extracted.exitStatus == 0 else {
            throw ManagedCodexRuntimeError.invalidPackage
        }
        try Data(release.archiveSHA256.utf8).write(to: staging.appendingPathComponent(".bmux-verified-archive"), options: .atomic)
        do { _ = try await validatedExecutable(in: staging) }
        catch { throw ManagedCodexRuntimeError.invalidPackage }
        do { try FileManager.default.moveItem(at: staging, to: destination) }
        catch {
            // Another bmux process may have published the same pin while this one downloaded.
            guard FileManager.default.fileExists(atPath: destination.path) else { throw error }
        }
        return try await validatedExecutable(in: destination)
    }

    private func validatedExecutable(in directory: URL) async throws -> URL {
        let executable = directory.appendingPathComponent("bin/codex")
        guard FileManager.default.isExecutableFile(atPath: executable.path),
              (try? String(contentsOf: directory.appendingPathComponent(".bmux-verified-archive"), encoding: .utf8)) == release.archiveSHA256 else {
            throw ManagedCodexRuntimeError.invalidInstallation
        }
        let version = await commands.runStandardOutput(directory: directory.path, executable: executable.path,
                                                      arguments: ["--version"], timeout: 5)
        guard version?.trimmingCharacters(in: .whitespacesAndNewlines) == "codex-cli " + release.version else {
            throw ManagedCodexRuntimeError.invalidInstallation
        }
        return executable
    }

    private func digest(of url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        while let bytes = try file.read(upToCount: 1_048_576), !bytes.isEmpty { hash.update(data: bytes) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
