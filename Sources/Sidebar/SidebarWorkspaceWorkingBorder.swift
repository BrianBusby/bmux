import SwiftUI

struct SidebarWorkspaceWorkingBorder: View {
    @Environment(\.colorScheme) private var colorScheme

    var cornerRadius: CGFloat = 6
    var lineWidth: CGFloat = 3
    var motion = SidebarWorkspaceWorkingBorderMotion()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                drawBorder(
                    context: &context,
                    size: size,
                    elapsedTime: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(outerRimColor, lineWidth: max(0.65, lineWidth * 0.2))
                .blendMode(.screen)
        }
        .overlay {
            RoundedRectangle(cornerRadius: max(0, cornerRadius - lineWidth), style: .continuous)
                .inset(by: lineWidth)
                .stroke(innerRimColor, lineWidth: max(0.55, lineWidth * 0.18))
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16), radius: 1.2, x: 0, y: 0.8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var outerRimColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.white.opacity(0.9)
    }

    private var innerRimColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.64) : Color.black.opacity(0.22)
    }

    private func drawBorder(
        context: inout GraphicsContext,
        size: CGSize,
        elapsedTime: TimeInterval
    ) {
        let effectiveLineWidth = min(max(2.2, lineWidth), max(1, min(size.width, size.height) * 0.42))
        let outerRect = CGRect(origin: .zero, size: size)
            .insetBy(dx: max(0.5, effectiveLineWidth * 0.18), dy: max(0.5, effectiveLineWidth * 0.18))
        let innerRect = outerRect.insetBy(dx: effectiveLineWidth, dy: effectiveLineWidth)
        guard innerRect.width > 0, innerRect.height > 0 else { return }

        var ringPath = Path(roundedRect: outerRect, cornerRadius: cornerRadius, style: .continuous)
        ringPath.addPath(Path(
            roundedRect: innerRect,
            cornerRadius: max(0, cornerRadius - effectiveLineWidth),
            style: .continuous
        ))

        context.drawLayer { layer in
            layer.clip(to: ringPath, style: FillStyle(eoFill: true))
            layer.fill(rectanglePath(outerRect), with: .color(baseEnamelColor))
            drawMovingBands(
                context: &layer,
                outerRect: outerRect,
                lineWidth: effectiveLineWidth,
                elapsedTime: elapsedTime
            )
            layer.fill(rectanglePath(outerRect), with: .linearGradient(
                glossGradient,
                startPoint: CGPoint(x: outerRect.minX, y: outerRect.minY),
                endPoint: CGPoint(x: outerRect.maxX, y: outerRect.maxY)
            ))
        }
    }

    private func drawMovingBands(
        context: inout GraphicsContext,
        outerRect: CGRect,
        lineWidth: CGFloat,
        elapsedTime: TimeInterval
    ) {
        let colorBandWidth = max(7, lineWidth * 3.35)
        let whiteBandWidth = colorBandWidth * 0.68
        let patternSpan = (2 * colorBandWidth) + (2 * whiteBandWidth)
        let activeMotion = SidebarWorkspaceWorkingBorderMotion(
            stripePeriod: motion.stripePeriod,
            stripeTravel: patternSpan
        )
        let offset = activeMotion.stripeOffset(atElapsedTime: elapsedTime)
        let coverage = outerRect.height * 1.6
        var x = outerRect.minX - coverage - patternSpan + offset

        while x < outerRect.maxX + coverage + patternSpan {
            drawBand(
                context: &context,
                x: x,
                width: colorBandWidth,
                coverage: coverage,
                rect: outerRect,
                color: Color(red: 0.84, green: 0.03, blue: 0.08)
            )
            drawBand(
                context: &context,
                x: x + colorBandWidth,
                width: whiteBandWidth,
                coverage: coverage,
                rect: outerRect,
                color: Color(red: 0.98, green: 0.97, blue: 0.91)
            )
            drawBand(
                context: &context,
                x: x + colorBandWidth + whiteBandWidth,
                width: colorBandWidth,
                coverage: coverage,
                rect: outerRect,
                color: Color(red: 0.03, green: 0.16, blue: 0.66)
            )
            drawBand(
                context: &context,
                x: x + (2 * colorBandWidth) + whiteBandWidth,
                width: whiteBandWidth,
                coverage: coverage,
                rect: outerRect,
                color: Color(red: 1.0, green: 0.99, blue: 0.94)
            )
            x += patternSpan
        }
    }

    private func drawBand(
        context: inout GraphicsContext,
        x: CGFloat,
        width: CGFloat,
        coverage: CGFloat,
        rect: CGRect,
        color: Color
    ) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: rect.minY - coverage))
        path.addLine(to: CGPoint(x: x + width, y: rect.minY - coverage))
        path.addLine(to: CGPoint(x: x + width + coverage, y: rect.maxY + coverage))
        path.addLine(to: CGPoint(x: x + coverage, y: rect.maxY + coverage))
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }

    private var baseEnamelColor: Color {
        colorScheme == .dark
            ? Color(red: 0.82, green: 0.84, blue: 0.88)
            : Color(red: 0.94, green: 0.95, blue: 0.97)
    }

    private var glossGradient: Gradient {
        Gradient(stops: [
            .init(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.16), location: 0.0),
            .init(color: Color.white.opacity(colorScheme == .dark ? 0.52 : 0.64), location: 0.18),
            .init(color: Color.clear, location: 0.44),
            .init(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.2), location: 0.78),
            .init(color: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.24), location: 1.0)
        ])
    }

    private func rectanglePath(_ rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        return path
    }
}
