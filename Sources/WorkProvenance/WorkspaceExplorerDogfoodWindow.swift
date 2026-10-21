#if DEBUG
import SwiftUI

/// Isolated native fixture window for history, reopen, reduced motion, and dense-layout dogfood.
@MainActor
struct WorkspaceExplorerDogfoodWindow: View {
    @State private var fixture = WorkspaceExplorerDogfoodFixture()

    var body: some View {
        WorkspaceExplorerWindowView(
            loadHistory: { fixture.load() }, reopenHistory: { fixture.reopen($0) },
            activateWorkspace: { _ in }, loadSessions: { fixture.sessions($0) },
            loadEvidence: { fixture.evidence($0) },
            loadMoreSessions: { id, _ in fixture.sessions(id) },
            clearArchive: { fixture.clear() }, liveStatusWorkspaces: { [] })
    }
}
#endif
