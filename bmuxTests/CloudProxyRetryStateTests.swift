import BmuxCore
import BmuxSidebar
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct CloudProxyRetryStateTests {
    @Test
    func proxyOnlyErrorsDoNotPolluteConnectedSidebar() {
        let workspace = Workspace()
        defer { workspace.teardownAllPanels() }
        let config = WorkspaceRemoteConfiguration(
            destination: "cloud VM",
            port: 22,
            identityFile: nil,
            sshOptions: [],
            localProxyPort: nil,
            relayPort: 64015,
            relayID: String(repeating: "e", count: 16),
            relayToken: String(repeating: "f", count: 64),
            localSocketPath: "/tmp/bmux-debug-test.sock",
            managedCloudVMID: "71smiccrg35sw9pydt8k",
            terminalStartupCommand: "bmux vm ssh-attach --id 71smiccrg35sw9pydt8k --default-freestyle-sshd",
            preserveAfterTerminalExit: true,
            persistentDaemonSlot: "bmux-default-freestyle-sshd-v1",
            skipDaemonBootstrap: true
        )

        workspace.configureRemoteConnection(config, autoConnect: false)
        #expect(workspace.activeRemoteTerminalSessionCount == 1)

        let proxyError = "Remote proxy to cloud VM unavailable: Failed to start local daemon proxy: timed out"
        workspace.applyRemoteConnectionStateUpdate(.error, detail: proxyError, target: "cloud VM")

        #expect(workspace.remoteConnectionState == .connected)
        #expect(workspace.statusEntries["remote.error"] == nil)
        #expect(workspace.logEntries.last(where: { $0.source == "remote-proxy" }) == nil)
        #expect(workspace.remoteStatusPayload()["connected"] as? Bool == true)

        workspace.statusEntries["remote.error"] = SidebarStatusEntry(
            key: "remote.error",
            value: "Remote proxy unavailable (cloud VM): \(proxyError)",
            icon: "exclamationmark.triangle.fill",
            color: nil,
            timestamp: Date()
        )
        workspace.logEntries.append(
            SidebarLogEntry(
                message: "Remote proxy unavailable (cloud VM): \(proxyError)",
                level: .error,
                source: "remote-proxy",
                timestamp: Date()
            )
        )
        workspace.applyRemoteConnectionStateUpdate(.reconnecting, detail: "Reconnecting to cloud VM", target: "cloud VM")

        #expect(workspace.remoteConnectionState == .connected)
        #expect(workspace.statusEntries["remote.error"] == nil)
        #expect(workspace.logEntries.last(where: { $0.source == "remote-proxy" }) == nil)

        workspace.logEntries.append(
            SidebarLogEntry(
                message: "Remote proxy unavailable (cloud VM): \(proxyError)",
                level: .error,
                source: "remote-proxy",
                timestamp: Date()
            )
        )

        #expect(
            workspace.sessionSnapshot(includeScrollback: false)
                .logEntries
                .last(where: { $0.source == "remote-proxy" }) == nil
        )

        var legacySnapshot = workspace.sessionSnapshot(includeScrollback: false)
        legacySnapshot.logEntries = [
            SessionLogEntrySnapshot(
                message: "Remote proxy unavailable (cloud VM): \(proxyError)",
                level: SidebarLogLevel.error.rawValue,
                source: "remote-proxy",
                timestamp: Date().timeIntervalSince1970
            )
        ]

        let restored = Workspace()
        defer { restored.teardownAllPanels() }
        restored.restoreSessionSnapshot(legacySnapshot)

        #expect(restored.logEntries.last(where: { $0.source == "remote-proxy" }) == nil)
    }
}
