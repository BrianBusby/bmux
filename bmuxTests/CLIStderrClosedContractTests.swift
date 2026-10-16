import Foundation
import Testing

struct CLIStderrClosedContractTests {
    private final class BundleToken {}

    @Test func unknownCommandPreservesExitCodeWhenStderrIsClosed() async throws {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: BundleToken.self)
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("stderr-closed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned stderr-closed fixture directory") }
        }
        let socketPath = root.appendingPathComponent("socket").path
        let password = "owned-stderr-contract"
        let server = CLISocketFixture(path: socketPath) { line in
            #expect(line == "auth \(password)")
            return line == "auth \(password)" ? "OK" : "ERROR: unexpected fixture request"
        }
        let arguments = [cli, "--socket", socketPath, "--password", password, "definitely-not-a-command"]
        let command = "exec " + arguments.map { "'" + $0.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
            .joined(separator: " ") + " 2>&-"
        let (outcome, requests) = try await server.capture {
            // Both outcomes join the child before the socket owner drains and closes.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await ShellContractProcess(
                    root: root, deadline: .seconds(5), terminationGrace: .milliseconds(200)
                ).run(executable: "/bin/sh", arguments: ["-c", command], environment: [
                    "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                    "XDG_CONFIG_HOME": root.appendingPathComponent("config").path,
                    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_CLI_SENTRY_DISABLED": "1",
                ]))
            } catch { return .failure(error) }
        }
        let result: ShellContractProcess.Result
        do { result = try outcome.get() }
        catch {
            let output = Result { try String(contentsOf: root.appendingPathComponent("stdout"), encoding: .utf8) }
            let errors = Result { try String(contentsOf: root.appendingPathComponent("stderr"), encoding: .utf8) }
            Issue.record(error, "Stderr-closed child failed after joined capture; stdout: \(output); stderr: \(errors)")
            throw error
        }
        #expect(requests == ["auth \(password)"])
        // Unknown commands deliberately use a short stderr error and exit 2, even when stderr is closed.
        #expect(result.terminatedNormally)
        #expect(result.status == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.isEmpty)
    }
}
