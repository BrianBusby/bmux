import SwiftUI

/// Repository identity shown above a workspace card's title.
struct WorkspaceRepositoryLabel: View {
    let name: String
    let font: Font

    var body: some View {
        Text(name)
            .font(font)
            .foregroundStyle(Color(red: 57 / 255, green: 1, blue: 20 / 255))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
