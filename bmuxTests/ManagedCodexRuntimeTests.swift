import BmuxFoundation
import CryptoKit
import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@Suite struct ManagedCodexRuntimeTests {
    @Test func concurrentLaunchesInstallOnceAndReuseTheFullPackageOffline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (archive, release) = try await fixture(in: root)
        let downloads = ManagedCodexDownloadFixture(archive: archive)
        let installed = root.appendingPathComponent("managed")
        let runtime = ManagedCodexRuntime(root: installed, release: release, download: { try await downloads.download($0) })
        let paths = try await withThrowingTaskGroup(of: URL.self) { group in
            for _ in 0..<8 { group.addTask { try await runtime.executable() } }
            var paths: [URL] = []
            for try await path in group { paths.append(path) }
            return paths
        }
        #expect(Set(paths).count == 1)
        #expect(await downloads.attempts == 1)
        let destination = installed.appendingPathComponent(release.directoryName)
        #expect(try String(contentsOf: destination.appendingPathComponent("codex-resources/helper"), encoding: .utf8) == "resource")
        #expect(FileManager.default.isExecutableFile(atPath: destination.appendingPathComponent("bin/codex-code-mode-host").path))
        let offline = ManagedCodexRuntime(root: installed, release: release, download: { _ in throw URLError(.notConnectedToInternet) })
        #expect(try await offline.executable() == paths[0])
        #expect(try FileManager.default.contentsOfDirectory(atPath: installed.path) == [release.directoryName])
    }

    @Test func failedDownloadLeavesNoPublishedRuntimeAndCanRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (archive, release) = try await fixture(in: root)
        let downloads = ManagedCodexDownloadFixture(archive: archive, failuresRemaining: 1)
        let installed = root.appendingPathComponent("managed")
        let runtime = ManagedCodexRuntime(root: installed, release: release, download: { try await downloads.download($0) })
        await #expect(throws: ManagedCodexRuntimeError.downloadFailed) { _ = try await runtime.executable() }
        #expect(try FileManager.default.contentsOfDirectory(atPath: installed.path).isEmpty)
        _ = try await runtime.executable()
        #expect(await downloads.attempts == 2)
    }

    @Test func checksumMismatchIsRejectedBeforeExtraction() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (archive, release) = try await fixture(in: root)
        try Data("corrupt download".utf8).write(to: archive)
        let downloads = ManagedCodexDownloadFixture(archive: archive)
        let installed = root.appendingPathComponent("managed")
        let runtime = ManagedCodexRuntime(root: installed, release: release, download: { try await downloads.download($0) })
        await #expect(throws: ManagedCodexRuntimeError.invalidPackage) { _ = try await runtime.executable() }
        #expect(try FileManager.default.contentsOfDirectory(atPath: installed.path).isEmpty)
    }

    @Test func unexpectedVersionIsNeverPublished() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (archive, release) = try await fixture(in: root, actualVersion: "0.999.0")
        let downloads = ManagedCodexDownloadFixture(archive: archive)
        let installed = root.appendingPathComponent("managed")
        let runtime = ManagedCodexRuntime(root: installed, release: release, download: { try await downloads.download($0) })
        await #expect(throws: ManagedCodexRuntimeError.invalidPackage) { _ = try await runtime.executable() }
        #expect(try FileManager.default.contentsOfDirectory(atPath: installed.path).isEmpty)
    }

    @Test func twoAppInstancesPublishTheSamePinWithoutReplacingIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (archive, release) = try await fixture(in: root)
        let downloads = ManagedCodexDownloadFixture(archive: archive)
        let installed = root.appendingPathComponent("managed")
        let first = ManagedCodexRuntime(root: installed, release: release, download: { try await downloads.download($0) })
        let second = ManagedCodexRuntime(root: installed, release: release, download: { try await downloads.download($0) })
        async let a = first.executable()
        async let b = second.executable()
        let (firstPath, secondPath) = try await (a, b)
        #expect(firstPath == secondPath)
        #expect(try FileManager.default.contentsOfDirectory(atPath: installed.path) == [release.directoryName])
    }

    private func fixture(in root: URL, actualVersion: String = "0.162.0") async throws -> (URL, ManagedCodexRelease) {
        let package = root.appendingPathComponent("package")
        let bin = package.appendingPathComponent("bin")
        let resources = package.appendingPathComponent("codex-resources")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        for name in ["codex", "codex-code-mode-host"] {
            let executable = bin.appendingPathComponent(name)
            try Data("#!/bin/sh\necho codex-cli \(actualVersion)\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        }
        try Data("resource".utf8).write(to: resources.appendingPathComponent("helper"))
        let archive = root.appendingPathComponent("package.tar.gz")
        let result = await CommandRunner().run(directory: root.path, executable: "/usr/bin/tar",
            arguments: ["-czf", archive.path, "-C", package.path, "."], timeout: 10)
        try #require(result.exitStatus == 0)
        let hash = SHA256.hash(data: try Data(contentsOf: archive)).map { String(format: "%02x", $0) }.joined()
        return (archive, ManagedCodexRelease(version: "0.162.0", target: "fixture", archiveSHA256: hash,
            archiveURL: URL(string: "https://example.invalid/codex.tar.gz")!))
    }
}
