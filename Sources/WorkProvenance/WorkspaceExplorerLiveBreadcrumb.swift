import SwiftUI

/// Explorer's hierarchy and retained-history action in the existing live titlebar.
struct WorkspaceExplorerLiveBreadcrumb: View {
    let collectionTitle: String
    let hasCollection: Bool
    let workspaceTitle: String
    let retainedSessionCount: Int?
    let leadingPadding: CGFloat
    let onAllProjects: () -> Void
    let onCollection: () -> Void
    let onHistory: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onAllProjects) {
                Label(String(localized: "explorer.allProjects", defaultValue: "All projects"),
                    systemImage: "arrow.left")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("explorer.allProjects")
            if hasCollection {
                Text("›").foregroundStyle(.secondary).accessibilityHidden(true)
                Button(collectionTitle, action: onCollection)
                    .buttonStyle(.borderless)
                    .lineLimit(1)
                    .accessibilityIdentifier("explorer.backToCollection")
            }
            Text("›").foregroundStyle(.secondary).accessibilityHidden(true)
            Text(workspaceTitle).lineLimit(1).fontWeight(.semibold)
            Spacer(minLength: 0)
            if let retainedSessionCount, retainedSessionCount > 0 {
                Button(String(format: String(localized: "explorer.viewRetainedHistoryCount",
                    defaultValue: "View retained history (%d sessions)"), retainedSessionCount),
                    action: onHistory)
                    .buttonStyle(.borderless)
                    .lineLimit(1)
                    .accessibilityIdentifier("explorer.viewRetainedHistory")
            }
        }
        .font(.system(size: 12))
        .padding(.leading, leadingPadding + 8)
        .padding(.trailing, 12)
    }
}
