import BmuxAgentChat
import Foundation
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

struct ConnectedCodexFixtureHost: ConnectedCodexHosting {
    let connection: CodexRPCConnection
    func launch(surfaceID: UUID, workingDirectory: String) async throws -> ConnectedCodexHost {
        ConnectedCodexHost(surfaceID: surfaceID, threadID: nil, processID: 0,
                           endpoint: URL(string: "ws://127.0.0.1:1")!, terminalCommand: "fixture",
                           connection: connection, control: nil)
    }
    func adoptOriginalThread(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost {
        var result = host
        result.threadID = "thread-a"
        result.control = CodexSharedControl(threadID: "thread-a", connection: connection)
        return result
    }
    func reconnect(_ host: ConnectedCodexHost) async throws -> ConnectedCodexHost { host }
    func endOwnedHost(surfaceID: UUID) async {}
}
