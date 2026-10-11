import SwiftUI

/// Approximates directional inner box-shadow edges with lightweight native strokes.
struct MatteSurfaceInnerEdge: View {
    let shape: RoundedRectangle
    let shadows: [MatteShadow]
    let isRecessed: Bool

    var body: some View {
        if isRecessed {
            ForEach(Array(shadows.enumerated()), id: \.offset) { _, shadow in
                recessedEdge(shadow)
            }
        } else if let highlight = shadows.first, let shade = shadows.dropFirst().first {
            shape.strokeBorder(
                LinearGradient(colors: [Color(nsColor: highlight.color), Color(nsColor: shade.color)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: width(for: highlight)
            )
            ForEach(Array(shadows.dropFirst(2).enumerated()), id: \.offset) { _, shadow in
                shape.strokeBorder(Color(nsColor: shadow.color), lineWidth: shadow.spread)
            }
        }
    }

    @ViewBuilder
    private func recessedEdge(_ shadow: MatteShadow) -> some View {
        let extent = width(for: shadow)
        let strokeWidth = shadows.map(\.spread).max() ?? extent
        if shadow.blur > 0 && strokeWidth > 0 {
            let count = Int(ceil(extent / strokeWidth))
            ForEach(0..<count, id: \.self) { index in
                let inset = Double(index) * strokeWidth
                shape.inset(by: inset)
                    .strokeBorder(gradient(for: shadow).opacity((extent - inset) / extent),
                                  lineWidth: min(strokeWidth, extent - inset))
            }
        } else {
            shape.strokeBorder(gradient(for: shadow), lineWidth: extent)
        }
    }

    private func width(for shadow: MatteShadow) -> Double {
        max(abs(shadow.offsetX), abs(shadow.offsetY), abs(shadow.spread)) + shadow.blur / 2
    }

    private func gradient(for shadow: MatteShadow) -> LinearGradient {
        let color = Color(nsColor: shadow.color)
        let colors = shadow.spread > 0 ? [color, color] : [color, color.opacity(0)]
        let reverse = shadow.offsetX < 0 || shadow.offsetY < 0
        return LinearGradient(colors: colors,
                              startPoint: reverse ? .bottomTrailing : .topLeading,
                              endPoint: reverse ? .topLeading : .bottomTrailing)
    }
}
