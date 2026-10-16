import Darwin
import Foundation
import Testing

/// Owns the fake repository's two Git completion gates and their native readiness source.
@MainActor
final class PendingDiffGitFixture {
    let root: URL
    let repo: URL
    let bin: URL
    private let input: Int32
    private let selected: Int32
    private let alternate: Int32
    private let readiness: CLISocketReadiness
    private let events: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var pending = Data()
    private var exits: [(source: any DispatchSourceProcess, events: AsyncStream<Void>)] = []

    init(root: URL) throws {
        self.root = root
        repo = root.appendingPathComponent("repo")
        bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        var descriptors: [Int32] = []
        do {
            for name in ["events", "selected", "alternate"] {
                let path = root.appendingPathComponent(name).path
                guard mkfifo(path, 0o600) == 0 else { throw POSIXError(.EIO) }
                let descriptor = open(path, O_RDWR | O_NONBLOCK | O_CLOEXEC)
                guard descriptor >= 0 else { throw POSIXError(.EIO) }
                descriptors.append(descriptor)
            }
            input = descriptors[0]; selected = descriptors[1]; alternate = descriptors[2]
            (events, continuation) = AsyncStream<Void>.makeStream()
            let signal = continuation
            // Existing native read-source owner also supports this fixture's FIFO descriptor.
            readiness = try CLISocketReadiness(descriptor: input) { signal.yield(()) }
        } catch {
            // CLISocketReadiness owns and closes its descriptor if its initializer fails.
            for descriptor in descriptors.dropFirst(descriptors.count == 3 ? 1 : 0) { Darwin.close(descriptor) }
            throw error
        }
    }

    func prepare() throws {
        let script = #"""
        #!/bin/bash
        if [[ ${1:-} == -C ]]; then shift 2; fi
        if [[ ${1:-} == rev-parse && ${2:-} == --show-toplevel ]]; then
          printf '%s\n' "$BMUX_FAKE_GIT_REPO_ROOT"; exit 0
        fi
        if [[ ${1:-} == symbolic-ref ]]; then printf 'origin/main\n'; exit 0; fi
        if [[ ${1:-} == for-each-ref ]]; then exit 0; fi
        if [[ ${1:-} != diff ]]; then exit 1; fi
        phase=selected
        for arg in "$@"; do [[ $arg == --cached ]] && phase=alternate; done
        : > "$BMUX_FAKE_GIT_ROOT/$phase-started"
        if [[ ! -f "$BMUX_FAKE_GIT_ROOT/$phase-released" ]]; then
          exec 8<>"$BMUX_FAKE_GIT_ROOT/$phase"
          exec 9<>"$BMUX_FAKE_GIT_ROOT/events"
          printf '%s %s %s\n' "$phase" "$$" "$PPID" >&9
          # Genuine bounded failure for an unreleased phase; no polling or settling delay.
          IFS= read -r -t 5 -u 8 release || exit 91
        fi
        [[ $phase == alternate ]] && exit 0
        printf '%s\n' 'diff --git a/large.txt b/large.txt' 'index 1111111..2222222 100644' \
          '--- a/large.txt' '+++ b/large.txt' '@@ -1 +1 @@' '-old line' '+new line'
        """#
        for (name, contents) in [("git", script), ("gh", "#!/bin/sh\nexit 1\n")] {
            let url = bin.appendingPathComponent(name)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    func waitForAlternate() async throws -> pid_t {
        for await _ in events {
            defer { readiness.acknowledge() }
            if let parent = try consumeAvailable() { return parent }
        }
        throw CancellationError()
    }

    private func consumeAvailable() throws -> pid_t? {
        var alternateParent: pid_t?
        var bytes = [UInt8](repeating: 0, count: 512)
        while true {
            let count = Darwin.read(input, &bytes, bytes.count)
            if count < 0, errno == EINTR { continue }
            if count < 0, errno == EAGAIN || errno == EWOULDBLOCK { break }
            guard count > 0 else { throw POSIXError(.EIO) }
            pending.append(contentsOf: bytes.prefix(count))
        }
        while let end = pending.firstIndex(of: 10) {
            let fields = String(decoding: pending.prefix(upTo: end), as: UTF8.self).split(separator: " ")
            pending.removeSubrange(...end)
            guard fields.count == 3, let pid = pid_t(fields[1]), let parent = pid_t(fields[2]) else {
                throw POSIXError(.EINVAL)
            }
            if kill(pid, 0) == 0 {
                let (ended, signal) = AsyncStream<Void>.makeStream()
                // Native exit observation is confined to the PID emitted by this owned gate child.
                let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit)
                source.setEventHandler { @Sendable in signal.yield(()); signal.finish() }
                source.resume()
                exits.append((source, ended))
            }
            if fields[0] == "alternate" { alternateParent = parent }
        }
        return alternateParent
    }

    func release(_ phase: String) throws {
        let marker = root.appendingPathComponent("\(phase)-released")
        if FileManager.default.fileExists(atPath: marker.path) { return }
        try Data().write(to: marker)
        let descriptor = phase == "selected" ? selected : alternate
        guard "\n".withCString({ Darwin.write(descriptor, $0, 1) }) == 1 else { throw POSIXError(.EIO) }
    }

    func close() async throws {
        var allJoined = true
        do { _ = try consumeAvailable() } catch {
            Issue.record(error, "Could not drain owned Git gate events during cleanup")
            allJoined = false
        }
        for (source, ended) in exits {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            let joined = await withTaskGroup(of: Bool.self) { group in
                group.addTask { for await _ in ended { return true }; return false }
                group.addTask {
                    // Cleanup failure bound for an observed owned child, not a latency assertion.
                    do { try await ContinuousClock().sleep(until: deadline) } catch { return false }
                    return false
                }
                let result = await group.next() ?? false
                group.cancelAll()
                return result
            }
            allJoined = allJoined && joined
            await withCheckedContinuation { continuation in
                source.setCancelHandler { @Sendable in continuation.resume() }
                source.cancel()
            }
        }
        continuation.finish()
        await readiness.close()
        Darwin.close(selected)
        Darwin.close(alternate)
        try #require(allJoined, "Owned Git gate child did not exit after release")
    }
}
