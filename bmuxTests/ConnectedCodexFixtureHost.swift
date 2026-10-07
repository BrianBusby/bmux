import BmuxAgentChat
import Foundation
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

struct ConnectedCodexFixtureHost: ConnectedCodexHosting {
    let connection: CodexRPCConnection
    let beforeLaunch: @MainActor @Sendable () async -> Void
    let beforeAdoption: @MainActor @Sendable () async -> Void
    let beforeReconnect: @MainActor @Sendable () async -> Void
    let replacementForReconnect: (@MainActor @Sendable (ConnectedCodexHost) async throws -> ConnectedCodexHost)?
    let onEnd: @MainActor @Sendable (UUID) async -> Void

    init(connection: CodexRPCConnection,
         beforeLaunch: @escaping @MainActor @Sendable () async -> Void = {},
         beforeAdoption: @escaping @MainActor @Sendable () async -> Void = {},
         beforeReconnect: @escaping @MainActor @Sendable () async -> Void = {},
         replacementForReconnect: (@MainActor @Sendable (ConnectedCodexHost) async throws -> ConnectedCodexHost)? = nil,
         onEnd: @escaping @MainActor @Sendable (UUID) async -> Void = { _ in }) {
        self.connection = connection
        self.beforeLaunch = beforeLaunch
        self.beforeAdoption = beforeAdoption
        self.beforeReconnect = beforeReconnect
        self.replacementForReconnect = replacementForReconnect
        self.onEnd = onEnd
    }
    func launch(surfaceID: UUID, workingDirectory: String, configuration: ConnectedCodexLaunchConfiguration) async throws -> ConnectedCodexHost {
        await beforeLaunch()
        return ConnectedCodexHost(surfaceID: surfaceID, threadID: nil, processID: 0,
                           endpoint: URL(string: "ws://127.0.0.1:1")!, terminalCommand: "fixture",
                           connection: connection, control: nil)
    }
    func adoptOriginalThread(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost {
        await beforeAdoption()
        var result = host
        result.threadID = "thread-a"
        result.control = CodexSharedControl(threadID: "thread-a", connection: connection)
        return result
    }
    func reconnect(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost {
        await beforeReconnect()
        if let replacementForReconnect { return try await replacementForReconnect(host) }
        return host
    }
    func endOwnedHost(surfaceID: UUID) async { await onEnd(surfaceID) }
}
