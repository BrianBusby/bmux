import SwiftUI

struct SelectedWorkspaceConnectedBorderGeometry: Equatable {
    struct Segment: Equatable {
        let start: CGPoint
        let end: CGPoint
    }

    let lineWidth: CGFloat
    let segments: [Segment]

    static func resolve(
        containerSize: CGSize,
        sidebarWidth: CGFloat,
        rightSidebarWidth: CGFloat,
        selectedRowFrame: CGRect?
    ) -> SelectedWorkspaceConnectedBorderGeometry {
        let width = max(0, containerSize.width)
        let height = max(0, containerSize.height)
        let contentMinX = min(max(sidebarWidth, 0), width)
        let contentMaxX = max(contentMinX, width - max(0, rightSidebarWidth))
        var segments: [Segment] = [
            Segment(start: CGPoint(x: contentMinX, y: 0), end: CGPoint(x: contentMaxX, y: 0)),
            Segment(start: CGPoint(x: contentMaxX, y: 0), end: CGPoint(x: contentMaxX, y: height)),
            Segment(start: CGPoint(x: contentMaxX, y: height), end: CGPoint(x: contentMinX, y: height)),
        ]

        if let selectedRowFrame, height > 0 {
            let rowTop = min(max(selectedRowFrame.minY, 0), height)
            let rowBottom = min(max(selectedRowFrame.maxY, rowTop), height)
            let tabMinX = min(max(selectedRowFrame.minX, 0), contentMinX)

            if rowTop > 0 {
                segments.append(Segment(start: CGPoint(x: contentMinX, y: 0), end: CGPoint(x: contentMinX, y: rowTop)))
            }
            if rowBottom < height {
                segments.append(Segment(start: CGPoint(x: contentMinX, y: rowBottom), end: CGPoint(x: contentMinX, y: height)))
            }
            if rowBottom > rowTop {
                segments.append(Segment(start: CGPoint(x: contentMinX, y: rowTop), end: CGPoint(x: tabMinX, y: rowTop)))
                segments.append(Segment(start: CGPoint(x: tabMinX, y: rowTop), end: CGPoint(x: tabMinX, y: rowBottom)))
                segments.append(Segment(start: CGPoint(x: tabMinX, y: rowBottom), end: CGPoint(x: contentMinX, y: rowBottom)))
            }
        } else {
            segments.append(Segment(start: CGPoint(x: contentMinX, y: 0), end: CGPoint(x: contentMinX, y: height)))
        }

        return SelectedWorkspaceConnectedBorderGeometry(
            lineWidth: SidebarWorkspaceSelectionBorderMetrics.connectedLineWidth,
            segments: segments
        )
    }
}

struct SelectedWorkspaceConnectedBorderOverlay: View {
    let sidebarWidth: CGFloat
    let rightSidebarWidth: CGFloat
    let selectedRowFrame: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let geometry = SelectedWorkspaceConnectedBorderGeometry.resolve(
                containerSize: proxy.size,
                sidebarWidth: sidebarWidth,
                rightSidebarWidth: rightSidebarWidth,
                selectedRowFrame: selectedRowFrame
            )
            Path { path in
                for segment in geometry.segments {
                    path.move(to: segment.start)
                    path.addLine(to: segment.end)
                }
            }
            .stroke(Color.black, style: StrokeStyle(lineWidth: geometry.lineWidth, lineCap: .square, lineJoin: .miter))
            .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}
