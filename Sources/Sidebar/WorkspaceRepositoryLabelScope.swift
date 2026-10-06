import SwiftUI

/// Observes repository identity above the list boundary and passes only name values to rows.
@MainActor
struct WorkspaceRepositoryLabelScope<Content: View>: View {
    let workspaces: [Workspace]
    @ViewBuilder let content: ([UUID: String]) -> Content
    @State private var repositoryNames: [UUID: String]?

    var body: some View {
        content(repositoryNames ?? WorkspaceRepositoryLabelObservation.snapshot(for: workspaces))
            .task(id: workspaces.map(ObjectIdentifier.init)) {
                let observation = WorkspaceRepositoryLabelObservation(workspaces: workspaces)
                defer { observation.cancel() }
                for await names in observation.updates {
                    guard !Task.isCancelled else { break }
                    repositoryNames = names
                }
            }
    }
}
