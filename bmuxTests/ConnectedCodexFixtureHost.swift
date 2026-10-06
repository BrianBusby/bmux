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
    let onEnd: @MainActor @Sendable (UUID) async -> Void

    init(connection: CodexRPCConnection,
         beforeLaunch: @escaping @MainActor @Sendable () async -> Void = {},
         beforeAdoption: @escaping @MainActor @Sendable () async -> Void = {},
         onEnd: @escaping @MainActor @Sendable (UUID) async -> Void = { _ in }) {
        self.connection = connection
        self.beforeLaunch = beforeLaunch
        self.beforeAdoption = beforeAdoption
        self.onEnd = onEnd
    }
    func launch(surfaceID: UUID, workingDirectory: String) async throws -> ConnectedCodexHost {
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
    func reconnect(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost { host }
    func endOwnedHost(surfaceID: UUID) async { await onEnd(surfaceID) }
}
