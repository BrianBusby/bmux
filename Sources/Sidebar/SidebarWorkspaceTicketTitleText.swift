import SwiftUI

struct SidebarWorkspaceTicketTitleText: View {
    let title: String
    let font: Font
    let color: Color
    let lineLimit: Int

    var body: some View {
        Text(title)
            .font(font)
            .foregroundColor(color)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }
}
