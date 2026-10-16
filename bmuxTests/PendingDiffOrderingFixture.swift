import Darwin
import Foundation
import Testing

/// Exercises pending-to-selected ordering with owned Git gates, CLI output and socket capture.
@MainActor
final class PendingDiffOrderingFixture {
    struct Snapshot: Sendable {
        let pendingHTML: String
        let diffStartedBeforeOpen: Bool
        let selectedReleasedBeforeOpen: Bool
        let selectedRedirected: Bool
        let alternateReleasedBeforeRedirect: Bool
        let cliAliveAtRedirect: Bool
        let result: ShellContractProcess.Result
        let diffStarted: Bool
        let finalHTML: String
        let patch: String
    }

    private struct Opening: Sendable {
        let file: URL
        let html: String
        let started: Bool
        let released: Bool
    }

    private enum Failure: Error { case deadline(String), missingEvent, invalidManifest }
    let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("pending-diff-\(UUID().uuidString)")
    private var viewer: URL { root.appendingPathComponent("viewer") }
    private var cli = ""
    private var socketCompletionDeadline: ContinuousClock.Instant?

    func run() async throws -> Snapshot {
        cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let git: PendingDiffGitFixture
        do { git = try PendingDiffGitFixture(root: root) } catch let setupError {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned root after Git fixture setup failure") }
            throw setupError
        }
        let outcome: Result<Snapshot, Error>
        do {
            try git.prepare()
            outcome = .success(try await capture(git: git))
        } catch { outcome = .failure(error) }
        do { try git.release("selected"); try git.release("alternate") }
        catch { Issue.record(error, "Could not release owned Git gates during cleanup") }
        // Retain and join cleanup independently of caller cancellation; native exit consumers must remain live.
        let cleanup = Task {
            var childrenJoined = true
            do { try await git.close() } catch {
                childrenJoined = false
                Issue.record(error, "Could not join owned Git gate children")
            }
            do {
                try await stopViewer()
                if childrenJoined { try FileManager.default.removeItem(at: root) }
            } catch { Issue.record(error, "Could not clean up owned pending-diff viewer") }
        }
        await cleanup.value
        return try outcome.get()
    }

    private func capture(git: PendingDiffGitFixture) async throws -> Snapshot {
        let (openings, signal) = AsyncStream<Opening>.makeStream()
        defer { signal.finish() }
        let viewer = viewer, root = root
        let password = UUID().uuidString
        let socket = CLISocketFixture(path: root.appendingPathComponent("socket").path) { line in
            if line == "auth \(password)" { return "OK" }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            guard request["method"] as? String == "browser.open_split",
                  let params = request["params"] as? [String: Any], let url = params["url"] as? String else {
                return "{\"id\":\"\(id)\",\"ok\":false,\"error\":{\"code\":\"unexpected\"}}"
            }
            let file = try Self.file(for: url, root: viewer)
            signal.yield(Opening(file: file, html: try String(contentsOf: file, encoding: .utf8),
                                 started: FileManager.default.fileExists(atPath: root.appendingPathComponent("selected-started").path),
                                 released: FileManager.default.fileExists(atPath: root.appendingPathComponent("selected-released").path)))
            return String(decoding: try JSONSerialization.data(withJSONObject: [
                "id": id, "ok": true, "result": ["surface_id": "surface-id", "pane_id": "pane-id", "url": url],
            ]), as: UTF8.self)
        }
        let environment = [
            "PATH": "\(git.bin.path):/usr/bin:/bin:/usr/sbin:/sbin", "HOME": root.path,
            "CFFIXED_USER_HOME": root.path, "XDG_CONFIG_HOME": root.path, "TMPDIR": root.path,
            "BMUX_DIFF_VIEWER_DIRECTORY": viewer.path, "BMUX_SOCKET_PATH": socket.path,
            "BMUX_SOCKET_PASSWORD": password, "BMUX_CLI_SENTRY_DISABLED": "1",
            "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1", "BMUX_DEBUG_LOG": root.appendingPathComponent("debug").path,
            "BMUX_FAKE_GIT_REPO_ROOT": git.repo.path, "BMUX_FAKE_GIT_ROOT": root.path,
        ]
        let (outcome, _) = try await socket.capture(operation: { @Sendable in
            await self.produce(git: git, openings: openings, environment: environment)
        })
        if let deadline = socketCompletionDeadline, ContinuousClock.now >= deadline {
            throw Failure.deadline("socket completion")
        }
        return try outcome.get()
    }

    private func produce(
        git: PendingDiffGitFixture, openings: AsyncStream<Opening>, environment: [String: String]
    ) async -> Result<Snapshot, Error> {
        let root = root, viewer = viewer
        // Additional outer ceiling is the sum of the original three 5s CLI phases; each phase stays bounded below.
        let producer = Task { try await ShellContractProcess(root: git.repo, deadline: .seconds(15)).run(
            executable: cli, arguments: ["diff", "--unstaged", "--cwd", git.repo.path,
                                         "--title", "Slow diff", "--no-focus"], environment: environment)
        }
        do {
            let opening = try await bounded("pending open") {
                for await opening in openings { return opening }
                throw Failure.missingEvent
            }
            try git.release("selected")
            let parent = try await bounded("selected redirect before cached completion") {
                try await git.waitForAlternate()
            }
            let redirected = try String(contentsOf: opening.file, encoding: .utf8).contains("data-bmux-diff-redirect=")
            let released = FileManager.default.fileExists(atPath: root.appendingPathComponent("alternate-released").path)
            let alive = kill(parent, 0) == 0 && Self.executablePath(parent) == URL(fileURLWithPath: cli).resolvingSymlinksInPath().path
            try git.release("alternate")
            let result = try await bounded("CLI completion", onFailure: { producer.cancel() }) { try await producer.value }
            socketCompletionDeadline = ContinuousClock.now.advanced(by: .seconds(5))
            var final = opening.file
            for _ in 0..<4 {
                let html = try String(contentsOf: final, encoding: .utf8)
                guard let url = Self.redirect(html) else { break }
                final = try Self.file(for: url, root: viewer)
            }
            return .success(Snapshot(pendingHTML: opening.html, diffStartedBeforeOpen: opening.started,
                selectedReleasedBeforeOpen: opening.released, selectedRedirected: redirected,
                alternateReleasedBeforeRedirect: released, cliAliveAtRedirect: alive, result: result,
                diffStarted: FileManager.default.fileExists(atPath: root.appendingPathComponent("selected-started").path),
                finalHTML: try String(contentsOf: final, encoding: .utf8),
                patch: try String(contentsOf: final.deletingPathExtension().appendingPathExtension("patch"), encoding: .utf8)))
        } catch {
            do { try git.release("selected"); try git.release("alternate") }
            catch { Issue.record(error, "Could not release owned Git gates before producer cancellation") }
            producer.cancel()
            _ = await producer.result
            return .failure(error)
        }
    }

    private func bounded<T: Sendable>(
        _ phase: String, onFailure: @escaping @MainActor @Sendable () -> Void = {},
        operation: @escaping @MainActor @Sendable () async throws -> T
    ) async throws -> T {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        return try await withThrowingTaskGroup(of: T.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await operation() }
            group.addTask {
                // Original per-phase failure deadline, not a settling delay.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.deadline(phase)
            }
            do {
                let result = try await group.next()
                return try #require(result)
            } catch {
                onFailure()
                throw error
            }
        }
    }

    private func stopViewer() async throws {
        let stateURL = viewer.appendingPathComponent(".server.json")
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return }
        let state = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: stateURL)) as? [String: Any])
        let pid = try #require(state["pid"] as? Int32)
        let expected = URL(fileURLWithPath: cli).resolvingSymlinksInPath().path
        try #require(pid > 1 && state["rootPath"] as? String == viewer.resolvingSymlinksInPath().path)
        guard kill(pid, 0) == 0 else { try #require(errno == ESRCH); return }
        try #require(Self.executablePath(pid) == expected)
        let (exits, signal) = AsyncStream<Void>.makeStream()
        // Join the exact owned manifest process through the maintained native process-exit boundary.
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit)
        source.setEventHandler { @Sendable in signal.yield(()); signal.finish() }
        source.resume()
        let outcome: Result<Void, Error>
        do {
            guard kill(pid, SIGTERM) == 0 || errno == ESRCH else { throw POSIXError(.EIO) }
            try await bounded("viewer cleanup") {
                for await _ in exits { return }
                throw Failure.missingEvent
            }
            outcome = .success(())
        } catch { outcome = .failure(error) }
        signal.finish()
        await withCheckedContinuation { continuation in
            source.setCancelHandler { @Sendable in continuation.resume() }
            source.cancel()
        }
        try outcome.get()
    }

    private nonisolated static func executablePath(_ pid: pid_t) -> String? {
        var bytes = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &bytes, UInt32(bytes.count)) > 0 else { return nil }
        return URL(fileURLWithPath: String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)).resolvingSymlinksInPath().path
    }

    private nonisolated static func file(for rawURL: String, root: URL) throws -> URL {
        guard let url = URL(string: rawURL), url.scheme == "http", url.host == "127.0.0.1" else { throw Failure.invalidManifest }
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        let parts = path.split(separator: "/")
        let token = try #require(parts.first)
        let manifest = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent(".manifest-\(token).json"))) as? [String: Any])
        let entries = try #require(manifest["files"] as? [[String: Any]])
        let entry = try #require(entries.first { $0["request_path"] as? String == "/" + parts.dropFirst().joined(separator: "/") && $0["mime_type"] as? String == "text/html" })
        return URL(fileURLWithPath: try #require(entry["file_path"] as? String))
    }

    private nonisolated static func redirect(_ html: String) -> String? {
        guard let start = html.range(of: "data-bmux-diff-redirect=\"")?.upperBound,
              let end = html[start...].firstIndex(of: "\"") else { return nil }
        return String(html[start..<end]).replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
    }
}
