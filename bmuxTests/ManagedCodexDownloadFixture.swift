import Foundation

actor ManagedCodexDownloadFixture {
    private let archive: URL
    private var failuresRemaining: Int
    private(set) var attempts = 0

    init(archive: URL, failuresRemaining: Int = 0) {
        self.archive = archive
        self.failuresRemaining = failuresRemaining
    }

    func download(_ url: URL) throws -> URL {
        attempts += 1
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw URLError(.notConnectedToInternet)
        }
        let copy = archive.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tar.gz")
        try FileManager.default.copyItem(at: archive, to: copy)
        return copy
    }
}
