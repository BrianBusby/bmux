import BmuxRemoteDaemon
import Foundation

/// Supplies one completed remote session to the real loopback bridge.
final class SSHExitedPTYClient: RemotePTYBridgeRPCClient {
    let events: AsyncStream<String>
    let continuation: AsyncStream<String>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func attachBridgePTY(
        sessionID: String, attachmentID: String, cols: Int, rows: Int,
        command: String?, requireExisting: Bool, queue: DispatchQueue,
        onEvent: @escaping (RemotePTYBridgeEvent) -> Void
    ) throws -> RemotePTYBridgeAttachment {
        continuation.yield("attach \(sessionID) \(attachmentID)")
        // The legacy RPC protocol requires event delivery on its supplied queue.
        queue.async { onEvent(.exit) }
        return RemotePTYBridgeAttachment(attachmentID: attachmentID, token: "control-cleanup-attachment")
    }

    func writePTY(
        sessionID: String, attachmentID: String, attachmentToken: String,
        data: Data, completion: @escaping ((any Error)?) -> Void
    ) {
        continuation.yield("write")
        completion(nil)
    }

    func detachPTY(sessionID: String, attachmentID: String, attachmentToken: String) {
        continuation.yield("detach")
    }
}
