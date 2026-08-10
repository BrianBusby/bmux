import BmuxSidebar
import SwiftUI

struct PullRequestStatusIcon: View {
    let status: SidebarPullRequestStatus
    let color: Color
    var fontScale: CGFloat = 1
    private static let closedFrameSize: CGFloat = 12
    private static let customFrameSize: CGFloat = 13

    private var closedFrameSize: CGFloat {
        Self.closedFrameSize * fontScale
    }

    private var customFrameSize: CGFloat {
        Self.customFrameSize * fontScale
    }

    var body: some View {
        switch status {
        case .open:
            PullRequestOpenIcon(color: color)
                .scaleEffect(fontScale)
                .frame(width: customFrameSize, height: customFrameSize)
        case .merged:
            PullRequestMergedIcon(color: color)
                .scaleEffect(fontScale)
                .frame(width: customFrameSize, height: customFrameSize)
        case .closed:
            BmuxSystemSymbolImage(magnified: "xmark.circle", pointSize: 7 * fontScale, weight: .regular)
                .foregroundColor(color)
                .frame(width: closedFrameSize, height: closedFrameSize)
        }
    }
}
