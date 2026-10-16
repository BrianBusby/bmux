import BmuxCore
import BmuxRemoteDaemon
import BmuxRemoteWorkspace
import Foundation
import Testing
@testable import BmuxRemoteSession

/// Immutable collaborators for bootstrap-only execution; starting unrelated session work is a fixture error.
final class RemoteDaemonBootstrapDependencies: RemoteSessionHosting, RemoteProxyBrokering,
    RemoteHostReachabilityProbing, RemoteRelayCommandRewriting, RemoteSessionBuildInfoProviding {
    let manifest: WorkspaceRemoteDaemonManifest

    init(manifest: WorkspaceRemoteDaemonManifest) { self.manifest = manifest }
    func appVersion() -> String? { manifest.appVersion }
    func embeddedDaemonManifest() -> WorkspaceRemoteDaemonManifest? { manifest }
    func executableDirectoryURL() -> URL? { nil }

    func publishConnectionState(_ state: WorkspaceRemoteConnectionState, detail: String?) {}
    func publishDaemonStatus(_ status: WorkspaceRemoteDaemonStatus) {}
    func publishProxyEndpoint(_ endpoint: BrowserProxyEndpoint?) {}
    func publishPortsSnapshot(detectedByPanel: [UUID: [Int]], detected: [Int]) {}
    func publishHeartbeat(count: Int, lastSeenAt: Date?) {}
    func publishBootstrapRemoteTTY(_ ttyName: String) {}

    func probe(destination: String, port: Int?, identityFile: String?, sshOptions: [String],
               completion: @escaping @Sendable (RemoteHostProbeOutcome) -> Void) {
        Issue.record("Bootstrap-only fixture must not start reachability work")
        completion(.indeterminate)
    }

    func rewriteRemoteRelayCommandLine(_ commandLine: Data, workspaceAliases: [UUID: UUID],
                                      surfaceAliases: [UUID: UUID]) -> Data { commandLine }

    func acquire(configuration: WorkspaceRemoteConfiguration, remotePath: String,
                 onUpdate: @escaping @Sendable (RemoteProxyBrokerUpdate) -> Void) -> RemoteProxyLease {
        preconditionFailure("Bootstrap-only fixture must not acquire a proxy")
    }
    func listPTY(configuration: WorkspaceRemoteConfiguration) throws -> [[String: Any]] {
        throw RemoteDaemonBootstrapFixture.Failure.unexpectedOperation
    }
    func closePTY(configuration: WorkspaceRemoteConfiguration, sessionID: String) throws {
        throw RemoteDaemonBootstrapFixture.Failure.unexpectedOperation
    }
    func resizePTY(configuration: WorkspaceRemoteConfiguration, sessionID: String, attachmentID: String,
                   attachmentToken: String, cols: Int, rows: Int) throws {
        throw RemoteDaemonBootstrapFixture.Failure.unexpectedOperation
    }
    func detachPTY(configuration: WorkspaceRemoteConfiguration, sessionID: String, attachmentID: String,
                   attachmentToken: String) throws {
        throw RemoteDaemonBootstrapFixture.Failure.unexpectedOperation
    }
    func startPTYBridge(configuration: WorkspaceRemoteConfiguration, sessionID: String, attachmentID: String,
                        command: String?, requireExisting: Bool) throws -> RemotePTYBridgeServer.Endpoint {
        throw RemoteDaemonBootstrapFixture.Failure.unexpectedOperation
    }
}
