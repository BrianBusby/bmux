import AppKit
import BmuxTerminal
import GhosttyKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns a real PTY capture child and observes its output after Ghostty parses it.
@MainActor
final class KittyClearHistoryFixture {
    let root: URL
    let surface: TerminalSurface
    let window: NSWindow
    let readyMarker = "BMUX_KBD_READY_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    let captureMarker = "BMUX_KBD_HEX_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    private let titles: AsyncStream<String>
    private let signal: AsyncStream<String>.Continuation
    private var observer: NSObjectProtocol?
    private var closed = false
    private let deadline: Duration

    init(deadline: Duration = .seconds(5)) throws {
        self.deadline = deadline
        root = FileManager.default.temporaryDirectory.appendingPathComponent("kitty-capture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let script = root.appendingPathComponent("capture.py")
        surface = TerminalSurface(tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil, workingDirectory: nil, initialCommand: "/usr/bin/python3 \(Self.quoted(script.path))")
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        (titles, signal) = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(4))
        do {
            try captureScript.write(to: script, atomically: true, encoding: .utf8)
        } catch {
            close()
            throw error
        }
        let surfaceID = surface.id, signal = signal
        // The existing native parser callback runs after the preceding visible marker.
        observer = NotificationCenter.default.addObserver(forName: .ghosttyDidSetTitle, object: nil, queue: nil) { note in
            guard let change = GhosttyTitleChange(notification: note), change.surfaceId == surfaceID else { return }
            signal.yield(change.title)
        }
    }

    func prepare() async throws {
        let readiness = TerminalRuntimeReadinessFixture(surface: surface)
        defer { readiness.close() }
        let content = try #require(window.contentView)
        let host = surface.hostedView
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        content.addSubview(host)
        content.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        host.setVisibleInUI(true)
        host.setActive(true)
        if surface.surface == nil { try await readiness.wait(timeout: deadline) }
        try await waitForParsedOutput(readyMarker)
    }

    func keyboardReset() async throws -> Data {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let integration = repo.appendingPathComponent("Resources/shell-integration/bmux-zsh-integration.zsh")
        let result = try await ShellContractProcess(root: root, deadline: deadline).run(executable: "/bin/zsh", arguments: [
            "-f", "-c", "source \(Self.quoted(integration.path)) >/dev/null 2>&1; _bmux_reset_terminal_keyboard_protocols",
        ], environment: ["BMUX_TEST_FORCE_KEYBOARD_RESET": "1"])
        try #require(result.status == 0, "Owned keyboard reset command failed: \(result.stderr)")
        return Data(result.stdout.utf8)
    }

    func processOutput(_ data: Data) throws {
        let runtime = try #require(surface.surface)
        data.withUnsafeBytes { bytes in
            if let base = bytes.baseAddress { ghostty_surface_process_output(runtime, base.assumingMemoryBound(to: CChar.self), UInt(bytes.count)) }
        }
    }

    func readText() throws -> String {
        let runtime = try #require(surface.surface)
        // SCREEN includes active content; the legacy SURFACE enum means history only.
        let selection = ghostty_selection_s(
            top_left: ghostty_point_s(tag: GHOSTTY_POINT_SCREEN, coord: GHOSTTY_POINT_COORD_TOP_LEFT, x: 0, y: 0),
            bottom_right: ghostty_point_s(tag: GHOSTTY_POINT_SCREEN, coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT, x: 0, y: 0),
            rectangle: false)
        var text = ghostty_text_s()
        try #require(ghostty_surface_read_text(runtime, selection, &text), "Complete terminal text selection failed")
        defer { ghostty_surface_free_text(runtime, &text) }
        guard let pointer = text.text, text.text_len > 0 else { return "" }
        return String(decoding: Data(bytes: pointer, count: Int(text.text_len)), as: UTF8.self)
    }

    func waitForCapture() async throws { try await waitForParsedOutput(captureMarker) }

    private func waitForParsedOutput(_ marker: String) async throws {
        let titles = titles, deadline = deadline
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await title in titles { if title == marker { return } }
                throw CancellationError()
            }
            group.addTask {
                // Original five-second output failure bound; cancellation joins this deadline.
                try await ContinuousClock().sleep(for: deadline)
                throw Failure.outputDeadline
            }
            _ = try await group.next()
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        signal.finish()
        surface.beginPortalCloseLifecycle(reason: "kitty.fixture.cleanup")
        // This existing test seam synchronously frees Ghostty, whose PTY owner signals and waits
        // for its child. Join before removing its script, including before PID publication.
        surface.releaseSurfaceForTesting()
        surface.teardownSurface()
        window.contentView = nil
        window.close()
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned Kitty capture directory") }
    }

    private static func quoted(_ value: String) -> String { "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'" }
    enum Failure: Error { case outputDeadline }

    private var captureScript: String {
        """
        import os, select, sys, termios, time, tty
        with open(\(String(reflecting: root.appendingPathComponent("child.pid").path)), 'w') as identity:
            identity.write(str(os.getpid()))
        fd = 0
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            sys.stdout.write('\\x1b[>3u\(readyMarker)\\n\\x1b]2;\(readyMarker)\\x07')
            sys.stdout.flush()
            data = bytearray()
            if select.select([sys.stdin], [], [], 2.0)[0]:
                data.extend(os.read(fd, 1))
                deadline = time.monotonic() + 1.0
                idle_deadline = time.monotonic() + 0.35
                while True:
                    remaining = min(deadline, idle_deadline) - time.monotonic()
                    if remaining <= 0 or not select.select([sys.stdin], [], [], remaining)[0]:
                        break
                    data.extend(os.read(fd, 64))
                    idle_deadline = time.monotonic() + 0.35
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        print('\\r\\n\(captureMarker)=' + data.hex(), flush=True)
        sys.stdout.write('\\x1b]2;\(captureMarker)\\x07')
        sys.stdout.flush()
        """
    }
}
