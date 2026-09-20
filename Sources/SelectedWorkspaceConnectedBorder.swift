import AppKit
import SwiftUI

/// Describes the perimeter that joins the selected workspace card to the
/// content frame in their common ContentView coordinate space.
struct SelectedWorkspaceConnectedBorderGeometry: Equatable {
    struct Segment: Equatable {
        let start: CGPoint
        let end: CGPoint
    }

    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    let workspaceTopY: CGFloat
    let segments: [Segment]
    let outlinePoints: [CGPoint]

    static func resolve(
        containerSize: CGSize,
        sidebarWidth: CGFloat,
        rightSidebarWidth: CGFloat,
        selectedRowFrame: CGRect?,
        workspaceTopY: CGFloat = 0
    ) -> Self {
        let width = max(0, containerSize.width)
        let height = max(0, containerSize.height)
        let contentMinX = min(max(sidebarWidth, 0), width)
        let contentMaxX = max(contentMinX, width - max(0, rightSidebarWidth))
        let topY = min(max(workspaceTopY, 0), height)
        let contentTopLeft = CGPoint(x: contentMinX, y: topY)
        let contentTopRight = CGPoint(x: contentMaxX, y: topY)
        let contentBottomRight = CGPoint(x: contentMaxX, y: height)
        let contentBottomLeft = CGPoint(x: contentMinX, y: height)

        var points = [contentTopLeft, contentTopRight, contentBottomRight, contentBottomLeft]
        var segments = [
            Segment(start: contentTopLeft, end: contentTopRight),
            Segment(start: contentTopRight, end: contentBottomRight),
            Segment(start: contentBottomRight, end: contentBottomLeft),
        ]

        guard let selectedRowFrame, height > topY else {
            segments.append(Segment(start: contentBottomLeft, end: contentTopLeft))
            return Self(
                lineWidth: SidebarWorkspaceSelectionBorderMetrics.connectedLineWidth,
                cornerRadius: SidebarWorkspaceSelectionBorderMetrics.connectedCornerRadius,
                workspaceTopY: topY,
                segments: segments,
                outlinePoints: points
            )
        }

        // Clip the selected card to the visible viewport. An off-screen row
        // must not leave a connector to coordinates outside the window.
        let rowTop = min(max(selectedRowFrame.minY, topY), height)
        let rowBottom = min(max(selectedRowFrame.maxY, rowTop), height)
        let cardMinX = min(max(selectedRowFrame.minX, 0), contentMinX)
        guard rowBottom > rowTop else {
            segments.append(Segment(start: contentBottomLeft, end: contentTopLeft))
            return Self(
                lineWidth: SidebarWorkspaceSelectionBorderMetrics.connectedLineWidth,
                cornerRadius: SidebarWorkspaceSelectionBorderMetrics.connectedCornerRadius,
                workspaceTopY: topY,
                segments: segments,
                outlinePoints: points
            )
        }

        if rowTop > topY {
            segments.append(Segment(
                start: CGPoint(x: contentMinX, y: topY),
                end: CGPoint(x: contentMinX, y: rowTop)
            ))
        }
        segments.append(Segment(
            start: CGPoint(x: contentMinX, y: rowTop),
            end: CGPoint(x: cardMinX, y: rowTop)
        ))
        segments.append(Segment(
            start: CGPoint(x: cardMinX, y: rowTop),
            end: CGPoint(x: cardMinX, y: rowBottom)
        ))
        segments.append(Segment(
            start: CGPoint(x: cardMinX, y: rowBottom),
            end: CGPoint(x: contentMinX, y: rowBottom)
        ))
        if rowBottom < height {
            segments.append(Segment(
                start: CGPoint(x: contentMinX, y: rowBottom),
                end: CGPoint(x: contentMinX, y: height)
            ))
        }
        // Keep one ordered contour for the joined perimeter. The previous
        // implementation appended connector points to a closed content
        // rectangle, which made the renderer draw the content's left edge
        // continuously through the selected card and produced a seam. The
        // selected card is an indentation in this contour: walk up the frame
        // to the card's bottom, across to the card, up its left edge, then
        // back to the frame before closing at the content top-left.
        points = [contentTopLeft, contentTopRight, contentBottomRight, contentBottomLeft]
        if rowBottom < height {
            points.append(CGPoint(x: contentMinX, y: rowBottom))
        }
        points.append(CGPoint(x: cardMinX, y: rowBottom))
        points.append(CGPoint(x: cardMinX, y: rowTop))
        if rowTop > topY {
            points.append(CGPoint(x: contentMinX, y: rowTop))
        }

        return Self(
            lineWidth: SidebarWorkspaceSelectionBorderMetrics.connectedLineWidth,
            cornerRadius: SidebarWorkspaceSelectionBorderMetrics.connectedCornerRadius,
            workspaceTopY: topY,
            segments: segments,
            outlinePoints: points
        )
    }

    func path() -> Path {
        var path = Path()
        guard outlinePoints.count > 2 else { return path }
        let radius = max(0, cornerRadius)
        for index in outlinePoints.indices {
            let previous = outlinePoints[(index - 1 + outlinePoints.count) % outlinePoints.count]
            let current = outlinePoints[index]
            let next = outlinePoints[(index + 1) % outlinePoints.count]
            let incomingLength = current.distance(to: previous)
            let outgoingLength = current.distance(to: next)
            guard incomingLength > 0, outgoingLength > 0 else { continue }
            let localRadius = min(radius, incomingLength / 2, outgoingLength / 2)
            let cornerStart = current.point(toward: previous, distance: localRadius)
            let cornerEnd = current.point(toward: next, distance: localRadius)
            if index == outlinePoints.startIndex {
                path.move(to: cornerStart)
            } else {
                path.addLine(to: cornerStart)
            }
            path.addQuadCurve(to: cornerEnd, control: current)
        }
        path.closeSubpath()
        return path
    }
}

/// Draws the selected workspace/content perimeter without intercepting input.
struct SelectedWorkspaceConnectedBorderOverlay: View {
    let sidebarWidth: CGFloat
    let rightSidebarWidth: CGFloat
    let selectedRowFrame: CGRect?
    let workspaceTopY: CGFloat
    let workspaceColorHex: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let geometry = SelectedWorkspaceConnectedBorderGeometry.resolve(
                containerSize: proxy.size,
                sidebarWidth: sidebarWidth,
                rightSidebarWidth: rightSidebarWidth,
                selectedRowFrame: selectedRowFrame,
                workspaceTopY: workspaceTopY
            )
            geometry.path()
                .stroke(
                    selectionBorderColor,
                    style: StrokeStyle(
                        lineWidth: geometry.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }

    private var selectionBorderColor: Color {
        let fallback = colorScheme == .dark ? "#B9A3FF" : "#6542AD"
        let resolvedHex = workspaceColorHex ?? fallback
        let color = WorkspaceTabColorSettings.displayNSColor(
            hex: resolvedHex,
            colorScheme: colorScheme,
            forceBright: true
        ) ?? NSColor.systemPurple
        return Color(nsColor: color).opacity(colorScheme == .dark ? 0.92 : 0.78)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }

    func point(toward other: CGPoint, distance: CGFloat) -> CGPoint {
        let totalDistance = self.distance(to: other)
        guard totalDistance > 0 else { return self }
        let ratio = distance / totalDistance
        return CGPoint(
            x: x + (other.x - x) * ratio,
            y: y + (other.y - y) * ratio
        )
    }
}
