import Darwin
import Foundation

/// Emits when the Provenance Engine SQLite store changes on disk.
@MainActor
final class WorkspaceDisplayCurrentStateFileWatcher {
    private let databaseURL: URL
    private let fileManager: FileManager
    private var continuation: AsyncStream<Void>.Continuation?
    private var sourcesByPath: [String: DispatchSourceFileSystemObject] = [:]

    init(databaseURL: URL, fileManager: FileManager = .default) {
        self.databaseURL = databaseURL
        self.fileManager = fileManager
    }

    deinit {
        for source in sourcesByPath.values {
            source.cancel()
        }
    }

    func changes() -> AsyncStream<Void> {
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        start(continuation: stream.continuation)
        stream.continuation.onTermination = { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
        return stream.stream
    }

    func stop() {
        for source in sourcesByPath.values {
            source.cancel()
        }
        sourcesByPath.removeAll()
        continuation = nil
    }

    private func start(continuation: AsyncStream<Void>.Continuation) {
        stop()
        self.continuation = continuation
        do {
            try fileManager.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            StartupBreadcrumbLog.append("workProvenance.displayCurrentState.watchDirectoryFailed", fields: [
                "directory": databaseURL.deletingLastPathComponent().path,
                "error": String(describing: error)
            ])
            continuation.finish()
            return
        }
        watchExistingStorePaths()
    }

    private func watchExistingStorePaths() {
        for url in candidateWatchURLs {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            watch(url)
        }
    }

    private var candidateWatchURLs: [URL] {
        let path = databaseURL.path
        return [
            databaseURL.deletingLastPathComponent(),
            databaseURL,
            URL(fileURLWithPath: "\(path)-journal", isDirectory: false),
            URL(fileURLWithPath: "\(path)-wal", isDirectory: false),
            URL(fileURLWithPath: "\(path)-shm", isDirectory: false)
        ]
    }

    private func watch(_ url: URL) {
        let path = url.path
        guard sourcesByPath[path] == nil else { return }
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        // DispatchSource bridges SQLite's cross-process filesystem writes into the main-actor stream.
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib, .extend, .link],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.handleChange(at: path)
            }
        }
        source.setCancelHandler {
            Darwin.close(fileDescriptor)
        }
        sourcesByPath[path] = source
        source.resume()
    }

    private func handleChange(at path: String) {
        if !fileManager.fileExists(atPath: path) {
            sourcesByPath.removeValue(forKey: path)?.cancel()
        }
        watchExistingStorePaths()
        continuation?.yield(())
    }
}
