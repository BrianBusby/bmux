import BmuxCore
import BmuxRemoteDaemon
import BmuxRemoteWorkspace
import CryptoKit
import Foundation
import Testing
@testable import BmuxRemoteSession

/// Owns verified binary acquisition and completion for a single bootstrap attempt.
final class RemoteDaemonBootstrapFixture: Sendable {
    enum Failure: Error { case deadline, unexpectedOperation }
    struct Outcome: Sendable {
        let events: [RemoteDaemonBootstrapProcessRunner.Event]
        let errorCode: Int?
    }

    let root: URL
    let cachedBinary: URL
    private let manifest: WorkspaceRemoteDaemonManifest
    private let timeout: Duration

    init(timeout: Duration) throws {
        self.timeout = timeout
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-bootstrap-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            let invalidURL = "http://["
            try #require(URL(string: invalidURL) == nil, "A cache miss must fail before any network operation")
            let bytes = Data("owned verified daemon".utf8)
            let checksum = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            let data = try JSONSerialization.data(withJSONObject: [
                "schemaVersion": 1, "appVersion": "owned-\(UUID())", "releaseTag": "owned",
                "releaseURL": invalidURL, "checksumsAssetName": "unused", "checksumsURL": invalidURL,
                "entries": [["goOS": "linux", "goArch": "amd64", "assetName": "owned-daemon",
                             "downloadURL": invalidURL, "sha256": checksum]],
            ])
            let manifest = try JSONDecoder().decode(WorkspaceRemoteDaemonManifest.self, from: data)
            let repository = RemoteDaemonManifestRepository(homeDirectory: root)
            let binary = try repository.cachedBinaryURL(version: manifest.appVersion, goOS: "linux", goArch: "amd64")
            try FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: binary)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
            let entry = try #require(manifest.entry(goOS: "linux", goArch: "amd64"))
            try #require(repository.validatedCachedBinary(entry: entry, version: manifest.appVersion) == binary)
            self.root = root
            cachedBinary = binary
            self.manifest = manifest
        } catch {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Failed to remove bootstrap fixture after setup failure") }
            throw error
        }
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Failed to remove owned bootstrap cache") }
    }

    func run(advertisesRequiredCapabilities: Bool) async throws -> Outcome {
        let events = AsyncStream<RemoteDaemonBootstrapProcessRunner.Event>.makeStream()
        let dependencies = RemoteDaemonBootstrapDependencies(manifest: manifest)
        let configuration = WorkspaceRemoteConfiguration(
            destination: "test@hpc.example", port: nil, identityFile: nil, sshOptions: [],
            localProxyPort: nil, relayPort: nil, relayID: nil, relayToken: nil, localSocketPath: nil,
            terminalStartupCommand: "ssh-pty-attach", preserveAfterTerminalExit: true
        )
        let required = RemoteDaemonRPCClient.requiredCapabilities(for: configuration)
        let coordinator = RemoteSessionCoordinator(
            host: dependencies, configuration: configuration, proxyBroker: dependencies,
            manifestRepository: RemoteDaemonManifestRepository(homeDirectory: root),
            processRunner: RemoteDaemonBootstrapProcessRunner(
                capabilities: advertisesRequiredCapabilities ? required : ["proxy.stream.push"],
                events: events.continuation
            ),
            reachabilityProbe: dependencies, relayCommandRewriter: dependencies, buildInfo: dependencies,
            daemonStrings: RemoteDaemonStrings(missingPersistentPTYCapability: "", missingRequiredFunctionality: ""),
            strings: RemoteSessionStrings(connectedVMNoProxyFormat: "%@", suspendedDetailFormat: "%@")
        )
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let worker = Task {
            await withCheckedContinuation { (completion: CheckedContinuation<Int?, Never>) in
                // Deliver to the existing coordinator's confinement queue; do not start session lifecycle work.
                coordinator.queue.async {
                    let errorCode = Self.bootstrap(coordinator)
                    coordinator.stopAllLocked()
                    events.continuation.finish()
                    completion.resume(returning: errorCode)
                }
            }
        }
        do {
            let captured = try await withThrowingTaskGroup(of: [RemoteDaemonBootstrapProcessRunner.Event].self) { group in
                group.addTask {
                    var captured: [RemoteDaemonBootstrapProcessRunner.Event] = []
                    for await event in events.stream { captured.append(event) }
                    return captured
                }
                group.addTask {
                    // Preserve the original two-second completion failure bound, cancelled when delivery finishes.
                    try await ContinuousClock().sleep(until: deadline)
                    throw Failure.deadline
                }
                defer { group.cancelAll() }
                let result = try await group.next()
                return try #require(result)
            }
            let errorCode = await worker.value
            try Task.checkCancellation()
            return Outcome(events: captured, errorCode: errorCode)
        } catch {
            _ = await worker.value
            throw error
        }
    }

    private static func bootstrap(_ coordinator: RemoteSessionCoordinator) -> Int? {
        let keys = ["BMUX_REMOTE_DAEMON_ALLOW_LOCAL_BUILD", "BMUX_REMOTE_DAEMON_BINARY"]
        let previous = keys.map { key in getenv(key).map { String(cString: $0) } }
        setenv(keys[0], "0", 1)
        unsetenv(keys[1])
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { setenv(key, value, 1) } else { unsetenv(key) }
            }
        }
        // The original two flags are restored before completion; no suspension occurs in this scope.
        do {
            _ = try coordinator.bootstrapDaemonLocked(requiredCapabilities: coordinator.requiredDaemonCapabilities)
            return nil
        } catch { return (error as NSError).code }
    }
}
