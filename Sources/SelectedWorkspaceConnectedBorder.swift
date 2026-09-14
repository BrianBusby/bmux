import SwiftUI

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
    ) -> SelectedWorkspaceConnectedBorderGeometry {
        let width = max(0, containerSize.width)
        let height = max(0, containerSize.height)
        let contentMinX = min(max(sidebarWidth, 0), width)
        let contentMaxX = max(contentMinX, width - max(0, rightSidebarWidth))
        let clampedWorkspaceTopY = min(max(workspaceTopY, 0), height)
        var segments: [Segment] = [
            Segment(
                start: CGPoint(x: contentMinX, y: clampedWorkspaceTopY),
                end: CGPoint(x: contentMaxX, y: clampedWorkspaceTopY)
            ),
            Segment(
                start: CGPoint(x: contentMaxX, y: clampedWorkspaceTopY),
                end: CGPoint(x: contentMaxX, y: height)
            ),
            Segment(start: CGPoint(x: contentMaxX, y: height), end: CGPoint(x: contentMinX, y: height)),
        ]
        var outlinePoints: [CGPoint] = [
            CGPoint(x: contentMinX, y: clampedWorkspaceTopY),
            CGPoint(x: contentMaxX, y: clampedWorkspaceTopY),
            CGPoint(x: contentMaxX, y: height),
            CGPoint(x: contentMinX, y: height),
        ]

        if let selectedRowFrame, height > clampedWorkspaceTopY {
            let rowTop = min(max(selectedRowFrame.minY, clampedWorkspaceTopY), height)
            let rowBottom = min(max(selectedRowFrame.maxY, rowTop), height)
            let tabMinX = min(max(selectedRowFrame.minX, 0), contentMinX)

            if rowTop > clampedWorkspaceTopY {
                segments.append(Segment(
                    start: CGPoint(x: contentMinX, y: clampedWorkspaceTopY),
                    end: CGPoint(x: contentMinX, y: rowTop)
                ))
            }
            if rowBottom < height {
                segments.append(Segment(start: CGPoint(x: contentMinX, y: rowBottom), end: CGPoint(x: contentMinX, y: height)))
            }
            if rowBottom > rowTop {
                segments.append(Segment(start: CGPoint(x: contentMinX, y: rowTop), end: CGPoint(x: tabMinX, y: rowTop)))
                segments.append(Segment(start: CGPoint(x: tabMinX, y: rowTop), end: CGPoint(x: tabMinX, y: rowBottom)))
                segments.append(Segment(start: CGPoint(x: tabMinX, y: rowBottom), end: CGPoint(x: contentMinX, y: rowBottom)))
                if rowBottom < height {
                    outlinePoints.append(CGPoint(x: contentMinX, y: rowBottom))
                }
                outlinePoints.append(CGPoint(x: tabMinX, y: rowBottom))
                outlinePoints.append(CGPoint(x: tabMinX, y: rowTop))
                if rowTop > clampedWorkspaceTopY {
                    outlinePoints.append(CGPoint(x: contentMinX, y: rowTop))
                }
            }
        } else {
            segments.append(Segment(
                start: CGPoint(x: contentMinX, y: clampedWorkspaceTopY),
                end: CGPoint(x: contentMinX, y: height)
            ))
        }

        return SelectedWorkspaceConnectedBorderGeometry(
            lineWidth: SidebarWorkspaceSelectionBorderMetrics.connectedLineWidth,
            cornerRadius: SidebarWorkspaceSelectionBorderMetrics.connectedCornerRadius,
            workspaceTopY: clampedWorkspaceTopY,
            segments: segments,
            outlinePoints: outlinePoints
        )
    }

    func path() -> Path {
        Self.roundedClosedPath(points: outlinePoints, radius: cornerRadius)
    }

    private static func roundedClosedPath(points: [CGPoint], radius: CGFloat) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        let clampedRadius = max(0, radius)
        guard clampedRadius > 0 else {
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
            return path
        }

        var didMove = false
        for index in points.indices {
            let previous = points[(index - 1 + points.count) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let incomingLength = current.distance(to: previous)
            let outgoingLength = current.distance(to: next)
            guard incomingLength > 0, outgoingLength > 0 else { continue }
            let localRadius = min(clampedRadius, incomingLength / 2, outgoingLength / 2)
            let cornerStart = current.point(toward: previous, distance: localRadius)
            let cornerEnd = current.point(toward: next, distance: localRadius)

            if didMove {
                path.addLine(to: cornerStart)
            } else {
                path.move(to: cornerStart)
                didMove = true
            }
            path.addQuadCurve(to: cornerEnd, control: current)
        }
        path.closeSubpath()
        return path
    }
}

struct SelectedWorkspaceConnectedBorderOverlay: View {
    let sidebarWidth: CGFloat
    let rightSidebarWidth: CGFloat
    let selectedRowFrame: CGRect?
    let workspaceTopY: CGFloat

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
                    Color.black,
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
