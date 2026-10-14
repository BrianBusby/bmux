import SwiftUI

/// Centers the title when possible, reserving leading controls and the actual trailing badge once.
struct WorkspaceTitlebarLayout: Layout {
    let leadingReservation: CGFloat
    let trailingInset: CGFloat
    let contentGap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let metrics = measure(proposal: proposal, subviews: subviews)
        return CGSize(width: metrics.width, height: max(metrics.title.height, metrics.badge.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = measure(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )
        if let title = subviews.first {
            let centeredX = (bounds.width - metrics.title.width) / 2
            let titleX = min(max(centeredX, metrics.titleLeading), metrics.titleTrailing - metrics.title.width)
            title.place(
                at: CGPoint(x: bounds.minX + titleX, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(metrics.title)
            )
        }
        if subviews.count > 1 {
            subviews[1].place(
                at: CGPoint(x: bounds.maxX - trailingInset, y: bounds.midY),
                anchor: .trailing,
                proposal: ProposedViewSize(metrics.badge)
            )
        }
    }

    private struct Measurements {
        let width: CGFloat
        let title: CGSize
        let badge: CGSize
        let titleLeading: CGFloat
        let titleTrailing: CGFloat
    }

    private func measure(proposal: ProposedViewSize, subviews: Subviews) -> Measurements {
        let intrinsicProposal = ProposedViewSize(width: nil, height: proposal.height)
        let titleIdeal = subviews.first?.sizeThatFits(intrinsicProposal) ?? .zero
        let hasBadge = subviews.count > 1
        let badgeIdeal = hasBadge ? subviews[1].sizeThatFits(intrinsicProposal) : .zero
        let badgeReservation = hasBadge ? badgeIdeal.width + contentGap : 0
        let idealWidth = leadingReservation + titleIdeal.width + badgeReservation + trailingInset
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? idealWidth
        let badge = hasBadge
            ? subviews[1].sizeThatFits(ProposedViewSize(
                width: min(badgeIdeal.width, max(0, width - trailingInset)), height: proposal.height
            ))
            : .zero
        let titleTrailing = max(0, width - trailingInset - (hasBadge ? badge.width + contentGap : 0))
        let titleLeading = min(max(0, leadingReservation), titleTrailing)
        let titleWidth = min(titleIdeal.width, titleTrailing - titleLeading)
        let title = subviews.first?.sizeThatFits(ProposedViewSize(width: titleWidth, height: proposal.height)) ?? .zero
        return Measurements(
            width: width, title: title, badge: badge,
            titleLeading: titleLeading, titleTrailing: titleTrailing
        )
    }
}
