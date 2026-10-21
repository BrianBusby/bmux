import Foundation
import Observation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite @MainActor
struct WorkspaceExplorerLiveNavigationTests {
    @Test
    func originInvalidatesTitlebarBeforeExplorerWindowRegisters() {
        let navigation = WorkspaceExplorerLiveNavigation()
        let changed = DispatchSemaphore(value: 0)
        withObservationTracking {
            _ = navigation.origin(for: nil)
        } onChange: {
            changed.signal()
        }
        navigation.opened(workspaceID: UUID(), from: "Unassigned workspaces")
        #expect(changed.wait(timeout: .now()) == .success)
    }
}
