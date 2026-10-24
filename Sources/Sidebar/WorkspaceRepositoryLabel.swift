import SwiftUI

/// Repository identity shown above a workspace card's title.
struct WorkspaceRepositoryLabel: View {
    let name: String
    let font: Font
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(name)
            .font(font)
            .foregroundStyle(Color(nsColor: WorkspaceRepoBadgeAppearanceColorPolicy.foregroundNSColor(
                colorScheme: colorScheme
            )))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
