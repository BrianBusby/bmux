import SwiftUI

/// Window menu entry points for the separate native Explorer.
struct WorkspaceExplorerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button(String(localized: "explorer.openWindow", defaultValue: "Project & Workspace Explorer")) {
                openWindow(id: "workspace-explorer")
            }
#if DEBUG
            Button(String(localized: "explorer.dogfoodWindow", defaultValue: "Explorer History Fixture")) {
                openWindow(id: "workspace-explorer-fixture")
            }
#endif
        }
    }
}
