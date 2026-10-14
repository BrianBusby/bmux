import AppKit
import BmuxTerminal
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
struct WorkspaceCreationConfigSanitizationTests {
    @Test func addWorkspacePassesSanitizedInheritedConfigTemplate() throws {
        let manager = ConfigSnapshotTabManager()
        defer { manager.tabs.forEach { $0.teardownRemoteConnection(); $0.teardownAllPanels() } }
        manager.installInjectedConfig(fontSize: 19)

        _ = manager.addWorkspace()

        let capturedConfig = try #require(manager.capturedConfigTemplate)

        #expect(abs(capturedConfig.fontSize - 19) <= 0.001)
        #expect(capturedConfig.workingDirectory == nil)
        #expect(capturedConfig.command == nil)
        #expect(capturedConfig.environmentVariables.isEmpty)
    }
}
