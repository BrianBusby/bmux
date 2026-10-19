import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct TerminalDefaultFileLaunchContractTests {
    @Test
    func buildsQuotedLaunchInputForTerminalCommandFile() throws {
        let contentType = DefaultTerminalRegistration.contentType(forIdentifier: "com.apple.terminal.shell-script")
        let url = URL(fileURLWithPath: "/tmp/bmux default's/Run Me.command")

        let request = try #require(TerminalDefaultFileOpenRequest(fileURL: url, contentType: contentType))

        // Decoded Foundation directory paths can retain a trailing slash.
        #expect(URL(fileURLWithPath: request.workingDirectory, isDirectory: true) ==
            URL(fileURLWithPath: "/tmp/bmux default's", isDirectory: true))
        #expect(request.initialInput == "'/tmp/bmux default'\\''s/Run Me.command'\n")
    }

    @Test
    func buildsLaunchInputForExtensionlessUnixExecutable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-terminal-default-executable-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { Issue.record(error, "Could not remove owned terminal-launch fixture directory") }
        }

        let executable = directory.appendingPathComponent("runme", isDirectory: false)
        try "#!/bin/sh\necho bmux\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let request = try #require(TerminalDefaultFileOpenRequest(fileURL: executable))

        #expect(URL(fileURLWithPath: request.workingDirectory, isDirectory: true) == directory)
        #expect(request.initialInput == "'\(executable.path)'\n")
    }
}
