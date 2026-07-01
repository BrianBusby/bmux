import SwiftUI

struct TronLoadingIndicatorPalette {
    let defaultColor: NSColor
    let backdropColor: NSColor

    static let `default` = TronLoadingIndicatorPalette(
        defaultColor: NSColor(hex: "#33F5FF") ?? NSColor.cyan,
        backdropColor: NSColor.black.withAlphaComponent(0.72)
    )
}

struct TronLoadingIndicator: View {
    var size: CGFloat = 44
    var color: Color = Color(nsColor: TronLoadingIndicatorPalette.default.defaultColor)
    var lineWidth: CGFloat = 4

    @State private var isAnimating = false

    private let duration: Double = 1.15
    private let backdropOpacity: CGFloat = TronLoadingIndicatorPalette.default.backdropColor.alphaComponent
    private let glowOpacity: Double = 0.34
    private let haloOpacity: Double = 0.12

    private let outerSegments: [ClosedRange<CGFloat>] = [
        0.00...0.11,
        0.20...0.32,
        0.46...0.57,
        0.68...0.81,
        0.89...0.98
    ]

    private let innerSegments: [ClosedRange<CGFloat>] = [
        0.04...0.15,
        0.27...0.41,
        0.54...0.65,
        0.78...0.92
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(backdropOpacity))

            Circle()
                .stroke(color.opacity(0.10), lineWidth: lineWidth)
                .padding(lineWidth * 0.5)

            SegmentedTronRing(
                segments: outerSegments,
                color: color,
                lineWidth: lineWidth
            )
            .padding(lineWidth * 0.5)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))

            SegmentedTronRing(
                segments: innerSegments,
                color: color,
                lineWidth: lineWidth * 0.85
            )
            .frame(width: size * 0.65, height: size * 0.65)
            .rotationEffect(.degrees(isAnimating ? -360 : 0))

            Circle()
                .fill(color.opacity(haloOpacity))
                .frame(width: size * 0.22, height: size * 0.22)

            Circle()
                .fill(color)
                .frame(width: size * 0.10, height: size * 0.10)
                .shadow(color: color.opacity(0.65), radius: size * 0.05)
        }
        .frame(width: size, height: size)
        .foregroundStyle(color)
        .shadow(color: color.opacity(glowOpacity), radius: size * 0.045)
        .onAppear {
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

private struct SegmentedTronRing: View {
    let segments: [ClosedRange<CGFloat>]
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.lowerBound, to: segment.upperBound)
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .butt
                        )
                    )
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TronLoadingIndicator(
            size: 96,
            color: Color(red: 0.20, green: 0.96, blue: 1.00),
            lineWidth: 6
        )
    }
}
