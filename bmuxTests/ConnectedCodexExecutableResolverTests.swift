import BmuxAgentChat
import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@Suite struct ConnectedCodexExecutableResolverTests {
    @Test func newLaunchResolvesUpdatedShellSelectionInsteadOfOldStandalone() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let local = root.appendingPathComponent(".local/bin"), bun = root.appendingPathComponent(".bun/bin")
        for directory in [local, bun] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let executable = directory.appendingPathComponent("codex")
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        }
        let shell = root.appendingPathComponent("zsh")
        let pathFile = root.appendingPathComponent("shell-path")
        let script = #"""
        #!/bin/sh
        printf 'shell startup message\n\000BMUX_CODEX_PATH\000'
        /bin/cat "$PATH_FIXTURE"
        """#
        try Data(script.utf8).write(to: shell)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: shell.path)
        let resolver = ConnectedCodexExecutableResolver(environment: ["HOME": root.path,
            "SHELL": shell.path, "PATH": local.path, "PATH_FIXTURE": pathFile.path])
        try Data("\(bun.path):\(local.path)\n".utf8).write(to: pathFile)
        let updated = try await resolver.resolve(workingDirectory: root.path)
        #expect(updated.executableURL == bun.appendingPathComponent("codex"))
        #expect(updated.environment["PATH"]?.hasPrefix(bun.path + ":") == true)
        // A long-lived app must resolve again after the user changes their shell selection.
        try Data("\(local.path):\(bun.path)\n".utf8).write(to: pathFile)
        let changed = try await resolver.resolve(workingDirectory: root.path)
        #expect(changed.executableURL == local.appendingPathComponent("codex"))
    }

    @Test func failedShellProbeDoesNotSilentlySelectAnOldFallback() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let shell = root.appendingPathComponent("zsh")
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: shell)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: shell.path)
        let resolver = ConnectedCodexExecutableResolver(environment: ["HOME": root.path, "SHELL": shell.path])
        await #expect(throws: CodexControlError.disconnected) {
            _ = try await resolver.resolve(workingDirectory: root.path)
        }
    }
}
