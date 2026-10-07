import Foundation

/// Provider hosting seam; presentation tests inject an owner without spawning a CLI.
protocol ConnectedCodexHosting: Sendable {
    func launch(surfaceID: UUID, workingDirectory: String, configuration: ConnectedCodexLaunchConfiguration) async throws -> ConnectedCodexHost
    func adoptOriginalThread(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost
    func reconnect(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost
    func endOwnedHost(surfaceID: UUID) async
}

extension ConnectedCodexHosting {
    func launch(surfaceID: UUID, workingDirectory: String) async throws -> ConnectedCodexHost {
        try await launch(surfaceID: surfaceID, workingDirectory: workingDirectory, configuration: .init())
    }
}
