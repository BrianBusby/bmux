import SwiftUI

struct TronLoadingIndicator: View {
    var size: CGFloat = 44
    var color: Color = .primary
    var lineWidth: CGFloat = 4

    private let parentPeriod: TimeInterval = 7
    private let childPeriod: TimeInterval = 1.5
    private let secondChildDelay: TimeInterval = -0.75

    var body: some View {
        TimelineView(.animation) { timeline in
            let parentAngle = rotationAngle(
                at: timeline.date,
                period: parentPeriod
            )
            let firstChildAngle = rotationAngle(
                at: timeline.date,
                period: childPeriod
            )
            let secondChildAngle = rotationAngle(
                at: timeline.date,
                period: childPeriod,
                delay: secondChildDelay
            )

            ZStack(alignment: .topLeading) {
                Circle()
                    .strokeBorder(color, lineWidth: lineWidth)
                    .frame(width: size, height: size)
                    .rotationEffect(parentAngle)

                orbitingCircle(rotation: firstChildAngle)
                orbitingCircle(rotation: secondChildAngle)
            }
        }
        .frame(width: size, height: size)
    }

    private var childSize: CGFloat {
        size * 0.5
    }

    private var childAnchor: UnitPoint {
        UnitPoint(
            x: 0.5,
            y: -1 - ((2 * lineWidth) / max(size, 1))
        )
    }

    private func orbitingCircle(rotation: Angle) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: lineWidth)
            .frame(width: childSize, height: childSize)
            .offset(x: (size - childSize) * 0.5, y: size + lineWidth)
            .rotationEffect(rotation, anchor: childAnchor)
    }

    private func rotationAngle(
        at date: Date,
        period: TimeInterval,
        delay: TimeInterval = 0
    ) -> Angle {
        let elapsed = date.timeIntervalSinceReferenceDate - delay
        let turns = elapsed
            .truncatingRemainder(dividingBy: period)
            / period
        return .degrees(turns * 360)
    }
}

#Preview {
    VStack(spacing: 40) {
        ZStack {
            Color.black

            TronLoadingIndicator(
                size: 96,
                color: .white,
                lineWidth: 6
            )
        }

        ZStack {
            Color.white

            TronLoadingIndicator(
                size: 96,
                color: .black,
                lineWidth: 6
            )
        }
    }
    .frame(width: 220, height: 320)
}
