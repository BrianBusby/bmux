import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite(.serialized)
struct FileExplorerGitStatusProviderTests {
    @Test
    func statusQueryDoesNotRefreshGitIndex() throws {
        let repoURL = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        try Self.initializeRepo(at: repoURL)

        let trackedURL = repoURL.appendingPathComponent("tracked.txt")
        try "one\n".write(to: trackedURL, atomically: true, encoding: .utf8)
        try Self.runGit(["add", "tracked.txt"], in: repoURL)
        try Self.runGit(["commit", "-m", "initial"], in: repoURL)

        let indexURL = repoURL.appendingPathComponent(".git/index")
        let indexBeforeStatus = try Data(contentsOf: indexURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 10)],
            ofItemAtPath: trackedURL.path
        )

        _ = GitStatusProvider().fetchStatus(directory: repoURL.path)

        let indexAfterStatus = try Data(contentsOf: indexURL)
        #expect(indexAfterStatus == indexBeforeStatus)
    }

    @Test
    func statusQueryPreservesQuotedAndEscapedFilenames() throws {
        let repoURL = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }
        try Self.initializeRepo(at: repoURL)

        let nestedURL = repoURL.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        let trackedURL = nestedURL.appendingPathComponent("quoted \"name\" and \\ slash.txt")
        try "one\n".write(to: trackedURL, atomically: true, encoding: .utf8)
        try Self.runGit(["add", "."], in: repoURL)
        try Self.runGit(["commit", "-m", "initial"], in: repoURL)
        try "two\n".write(to: trackedURL, atomically: true, encoding: .utf8)

        let status = GitStatusProvider().fetchStatus(directory: nestedURL.path)

        #expect(status[trackedURL.path] == .some(.modified))
    }

    @Test
    func statusQueryExcludesSiblingPathPrefixes() throws {
        let repoURL = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }
        try Self.initializeRepo(at: repoURL)

        let explorerRootURL = repoURL.appendingPathComponent("work", isDirectory: true)
        let siblingURL = repoURL.appendingPathComponent("workspace-sibling", isDirectory: true)
        try FileManager.default.createDirectory(at: explorerRootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: siblingURL, withIntermediateDirectories: true)

        let visibleURL = explorerRootURL.appendingPathComponent("tracked.txt")
        let siblingFileURL = siblingURL.appendingPathComponent("tracked.txt")
        try "one\n".write(to: visibleURL, atomically: true, encoding: .utf8)
        try "one\n".write(to: siblingFileURL, atomically: true, encoding: .utf8)
        try Self.runGit(["add", "."], in: repoURL)
        try Self.runGit(["commit", "-m", "initial"], in: repoURL)
        try "two\n".write(to: visibleURL, atomically: true, encoding: .utf8)
        try "two\n".write(to: siblingFileURL, atomically: true, encoding: .utf8)

        let status = GitStatusProvider().fetchStatus(directory: explorerRootURL.path)

        #expect(status[visibleURL.path] == .some(.modified))
        #expect(status[siblingFileURL.path] == nil)
        #expect(status[siblingURL.path] == nil)
    }

    @Test(arguments: [false, true])
    func statusQueryPreservesRequestedRootAliasAndExcludesSiblingPrefixes(usingSymbolicLink: Bool) async throws {
        let fixtureRoot = try Self.makeTemporaryDirectory()
        defer {
            do { try FileManager.default.removeItem(at: fixtureRoot) }
            catch { Issue.record(error) }
        }
        let repoURL = fixtureRoot.appendingPathComponent("repository", isDirectory: true)
        let homeURL = fixtureRoot.appendingPathComponent("home", isDirectory: true)
        let hooksURL = fixtureRoot.appendingPathComponent("empty-hooks", isDirectory: true)
        let nestedURL = repoURL.appendingPathComponent("work/nested", isDirectory: true)
        let siblingURL = repoURL.appendingPathComponent("workspace-sibling", isDirectory: true)
        for directory in [repoURL, homeURL, hooksURL, nestedURL, siblingURL] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let filename = "quoted \"name\" and \\ slash.txt"
        let trackedURL = nestedURL.appendingPathComponent(filename)
        let siblingFileURL = siblingURL.appendingPathComponent("tracked.txt")
        for file in [trackedURL, siblingFileURL] {
            try "one\n".write(to: file, atomically: true, encoding: .utf8)
        }
        let environment = [
            "PATH": "/usr/bin:/bin", "HOME": homeURL.path, "CFFIXED_USER_HOME": homeURL.path,
            "XDG_CONFIG_HOME": homeURL.path, "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_TERMINAL_PROMPT": "0",
            "GIT_AUTHOR_NAME": "bmux tests", "GIT_AUTHOR_EMAIL": "bmux@example.invalid",
            "GIT_COMMITTER_NAME": "bmux tests", "GIT_COMMITTER_EMAIL": "bmux@example.invalid",
        ]
        let process = ShellContractProcess(root: fixtureRoot)
        let gitPrefix = ["-C", repoURL.path, "-c", "commit.gpgSign=false", "-c", "core.hooksPath=\(hooksURL.path)"]
        for arguments in [["init", "--template=\(hooksURL.path)"], ["add", "."], ["commit", "-m", "initial"]] {
            let result = try await process.run(executable: "/usr/bin/git", arguments: gitPrefix + arguments, environment: environment)
            try #require(result.status == 0, "Owned repository preparation failed: \(result.stderr)")
        }
        let rootResult = try await process.run(
            executable: "/usr/bin/git", arguments: gitPrefix + ["rev-parse", "--show-toplevel"], environment: environment
        )
        try #require(rootResult.status == 0)
        // Git's own physical root keeps the control independent of Foundation's alias choices.
        let physicalRoot = URL(fileURLWithPath: rootResult.stdout.trimmingCharacters(in: .newlines), isDirectory: true)
        let aliasURL = fixtureRoot.appendingPathComponent("repository-alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: aliasURL, withDestinationURL: repoURL)
        for file in [trackedURL, siblingFileURL] {
            try "two\n".write(to: file, atomically: true, encoding: .utf8)
        }
        let requestedRepo = usingSymbolicLink ? aliasURL : physicalRoot
        let requestedRoot = requestedRepo.appendingPathComponent("work", isDirectory: true)
        let expectedDirectory = requestedRoot.appendingPathComponent("nested", isDirectory: true)
        let expectedFile = expectedDirectory.appendingPathComponent(filename)
        let status = GitStatusProvider(environment: environment).fetchStatus(directory: requestedRoot.path)

        #expect(status[expectedFile.path] == .some(.modified))
        #expect(status[expectedDirectory.path] == .some(.modified))
        #expect(status[requestedRepo.appendingPathComponent("workspace-sibling/tracked.txt").path] == nil)
        #expect(status[requestedRepo.appendingPathComponent("workspace-sibling").path] == nil)
        #expect(Set(status.keys) == Set([expectedFile.path, expectedDirectory.path]))
    }

    @Test
    func statusQueryMapsTypeChangedAndUnmergedEntries() throws {
        let repoURL = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let fakeGitURL = try Self.writeExecutableScript(
            #"""
            #!/bin/sh
            if [ "${BMUX_TEST_GIT_ENV:-}" != "expected" ]; then
                exit 3
            fi
            if [ "${GIT_OPTIONAL_LOCKS:-}" != "0" ]; then
                exit 4
            fi
            case "$1 $2" in
            "rev-parse --show-toplevel")
                printf '%s\n' "$BMUX_TEST_REPO_ROOT"
                ;;
            "status --porcelain=v1")
                printf ' T type-change.txt\0UU conflicted.txt\0'
                ;;
            *)
                exit 2
                ;;
            esac
            """#,
            named: "fake-git",
            in: repoURL
        )
        var environment = ProcessInfo.processInfo.environment
        environment["BMUX_TEST_GIT_ENV"] = "expected"
        environment["BMUX_TEST_REPO_ROOT"] = repoURL.path

        let status = GitStatusProvider(
            gitExecutableURL: fakeGitURL,
            environment: environment
        ).fetchStatus(directory: repoURL.path)

        #expect(
            status[repoURL.appendingPathComponent("type-change.txt").path] == .some(.modified)
        )
        #expect(
            status[repoURL.appendingPathComponent("conflicted.txt").path] == .some(.modified)
        )
    }

    @Test
    func sshStatusQueryUsesInjectedProcessEnvironment() throws {
        let repoURL = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let fakeSSHURL = try Self.writeExecutableScript(
            #"""
            #!/bin/sh
            if [ "${BMUX_TEST_SSH_ENV:-}" != "expected" ]; then
                exit 3
            fi
            printf '%s\n---GIT_STATUS---\n M remote.txt\0' "$BMUX_TEST_REPO_ROOT"
            """#,
            named: "fake-ssh",
            in: repoURL
        )
        var environment = ProcessInfo.processInfo.environment
        environment["BMUX_TEST_REPO_ROOT"] = repoURL.path
        environment["BMUX_TEST_SSH_ENV"] = "expected"

        let status = GitStatusProvider(
            sshExecutableURL: fakeSSHURL,
            environment: environment
        ).fetchStatusSSH(
            directory: repoURL.path,
            destination: "example.invalid",
            port: nil,
            identityFile: nil,
            sshOptions: []
        )

        #expect(
            status[repoURL.appendingPathComponent("remote.txt").path] == .some(.modified)
        )
    }

    @Test
    func sshStatusQueryOverridesHostConfiguredRemoteCommand() throws {
        // The remote git status runs as an ssh command-line command, which
        // OpenSSH refuses while a host-configured RemoteCommand is in effect
        // (issue #7246) — the argv must carry `-o RemoteCommand=none` before
        // the destination.
        let repoURL = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let argvLog = repoURL.appendingPathComponent("ssh-argv.txt")
        let fakeSSHURL = try Self.writeExecutableScript(
            #"""
            #!/bin/sh
            for arg in "$@"; do printf '%s\n' "$arg"; done > "$BMUX_TEST_SSH_ARGV_LOG"
            printf '%s\n---GIT_STATUS---\n M remote.txt\0' "$BMUX_TEST_REPO_ROOT"
            """#,
            named: "fake-ssh",
            in: repoURL
        )
        var environment = ProcessInfo.processInfo.environment
        environment["BMUX_TEST_REPO_ROOT"] = repoURL.path
        environment["BMUX_TEST_SSH_ARGV_LOG"] = argvLog.path

        let status = GitStatusProvider(
            sshExecutableURL: fakeSSHURL,
            environment: environment
        ).fetchStatusSSH(
            directory: repoURL.path,
            destination: "example.invalid",
            port: nil,
            identityFile: nil,
            sshOptions: []
        )

        #expect(
            status[repoURL.appendingPathComponent("remote.txt").path] == .some(.modified)
        )
        let argv = try String(contentsOf: argvLog, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let overrideIndex = argv.indices.dropLast().first {
            argv[$0] == "-o" && argv[$0 + 1] == "RemoteCommand=none"
        }
        let destinationIndex = argv.firstIndex(of: "example.invalid")
        #expect(overrideIndex != nil, "\(argv)")
        #expect(destinationIndex != nil, "\(argv)")
        if let overrideIndex, let destinationIndex {
            #expect(overrideIndex < destinationIndex)
        }
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-file-explorer-git-status-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    private static func writeExecutableScript(
        _ contents: String, named name: String, in directory: URL
    ) throws -> URL {
        let scriptURL = directory.appendingPathComponent(name)
        try contents.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    private static func initializeRepo(at repoURL: URL) throws {
        try Self.runGit(["init"], in: repoURL)
        try Self.runGit(["config", "user.name", "bmux tests"], in: repoURL)
        try Self.runGit(["config", "user.email", "bmux@example.invalid"], in: repoURL)
    }

    private static func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        try #require(process.terminationStatus == 0, "git \(arguments.joined(separator: " ")) failed")
    }
}
