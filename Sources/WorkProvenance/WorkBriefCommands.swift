import SwiftUI

/// Window-menu entry for the built-in Work Brief.
struct WorkBriefCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button(String(localized: "workBrief.openWindow", defaultValue: "Work Brief")) {
                openWindow(id: "work-brief")
            }
        }
    }
}
