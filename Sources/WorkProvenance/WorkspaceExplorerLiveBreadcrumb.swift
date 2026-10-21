import SwiftUI

/// An Explorer return affordance in the existing live workspace titlebar.
struct WorkspaceExplorerLiveBreadcrumb: View {
    let collectionTitle: String
    let workspaceTitle: String
    let leadingPadding: CGFloat
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onBack) {
                Label(String(format: String(localized: "explorer.backToCollection",
                    defaultValue: "Back to %@"), collectionTitle), systemImage: "arrow.left")
                    .lineLimit(1)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("explorer.backToCollection")
            Text("›").foregroundStyle(.secondary).accessibilityHidden(true)
            Text(collectionTitle).lineLimit(1).foregroundStyle(.secondary)
            Text("›").foregroundStyle(.secondary).accessibilityHidden(true)
            Text(workspaceTitle).lineLimit(1).fontWeight(.semibold)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .padding(.leading, leadingPadding + 8)
        .padding(.trailing, 12)
    }
}
