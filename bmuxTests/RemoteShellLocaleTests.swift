import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct RemoteShellLocaleTests {
    @Test func remoteUTF8LocaleSetupLinesSeedUTF8LocaleWhenMissing() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-remote-locale-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned locale fixture directory") }
        }
        let script = (RemoteShellEnvironment.utf8LocaleSetupLines() + [
            #"printf '%s' "${LANG}|${LC_CTYPE}|${LC_ALL}""#,
        ]).joined(separator: "\n")
        // The throwing, joined call retains the original plain five-second no-timeout oracle.
        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: "/usr/bin/env",
            arguments: ["LANG=", "LC_CTYPE=", "LC_ALL=", "/bin/sh", "-c", script],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                "TMPDIR": root.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
                "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
            ]
        )
        #expect(result.status == 0, "Shell exit status: \(result.stderr)")
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "C.UTF-8|C.UTF-8|C.UTF-8")
    }
}
