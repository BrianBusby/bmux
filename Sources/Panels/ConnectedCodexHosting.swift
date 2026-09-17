import Foundation

/// Provider hosting seam; presentation tests inject an owner without spawning a CLI.
protocol ConnectedCodexHosting: Sendable {
    func launch(surfaceID: UUID, workingDirectory: String) async throws -> ConnectedCodexHost
    func adoptOriginalThread(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost
    func reconnect(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost
    func endOwnedHost(surfaceID: UUID) async
}
