import SwiftUI

/// Owns live card observation; rows receive values and action closures only.
@MainActor
struct WorkspaceReferenceCardScope<Content: View>: View {
    let workspaces: [Workspace]
    let project: @MainActor (Workspace) -> WorkspaceReferenceCardSnapshot
    @ViewBuilder let content: ([WorkspaceReferenceCardSnapshot]) -> Content
    @State private var revision: UInt64 = 0

    var body: some View {
        let _ = revision
        // Parent-owned inputs (such as group names) also reproject on parent updates.
        content(workspaces.map(project))
            .task(id: workspaces.map(ObjectIdentifier.init)) {
                let observation = WorkspaceReferenceCardObservation(workspaces: workspaces, project: project)
                defer { observation.cancel() }
                for await _ in observation.updates {
                    guard !Task.isCancelled else { break }
                    revision &+= 1
                }
            }
    }
}
