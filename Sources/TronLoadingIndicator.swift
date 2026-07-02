import SwiftUI

struct TronLoadingIndicator: View {
    var size: CGFloat = 44
    var color: Color = .primary
    var lineWidth: CGFloat = 4

    private let parentPeriod: TimeInterval = 7
    private let handoffPeriod: TimeInterval = 1.5
    private let fastTurnsPerHalfCycle: CGFloat = 0.66
    private let slowTurnsPerHalfCycle: CGFloat = 0.16

    var body: some View {
        TimelineView(.animation) { timeline in
            let parentAngle = rotationAngle(
                at: timeline.date,
                period: parentPeriod
            )
            let childPhases = handoffOrbitPhases(at: timeline.date)
            let orbitDrift = rotationAngle(
                at: timeline.date,
                period: parentPeriod
            ).radians / (2 * .pi)

            ZStack(alignment: .topLeading) {
                Circle()
                    .strokeBorder(color, lineWidth: effectiveLineWidth)
                    .frame(width: parentSize, height: parentSize)
                    .position(x: center, y: center)
                    .rotationEffect(parentAngle)

                orbitingCircle(phase: childPhases.first + orbitDrift)
                orbitingCircle(phase: childPhases.second + orbitDrift)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }

    private var center: CGFloat {
        size * 0.5
    }

    private var parentSize: CGFloat {
        size * 0.48
    }

    private var childSize: CGFloat {
        parentSize * 0.46
    }

    private var effectiveLineWidth: CGFloat {
        min(lineWidth, max(0.6, parentSize * 0.08))
    }

    private var orbitGap: CGFloat {
        max(0.4, effectiveLineWidth * 0.75)
    }

    private var orbitRadius: CGFloat {
        (parentSize * 0.5) + (childSize * 0.5) + orbitGap
    }

    private func orbitingCircle(phase: CGFloat) -> some View {
        let radians = phase * 2 * .pi
        let x = center + CGFloat(sin(radians)) * orbitRadius
        let y = center + CGFloat(cos(radians)) * orbitRadius

        return Circle()
            .strokeBorder(color, lineWidth: effectiveLineWidth)
            .frame(width: childSize, height: childSize)
            .position(x: x, y: y)
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

    private func handoffOrbitPhases(at date: Date) -> (first: CGFloat, second: CGFloat) {
        let halfCycle = handoffPeriod * 0.5
        let fullLoop = handoffPeriod * 2
        let elapsed = date.timeIntervalSinceReferenceDate
        let loopIndex = floor(elapsed / fullLoop)
        let loopElapsed = elapsed - (loopIndex * fullLoop)
        let halfSegment = min(3, Int(floor(loopElapsed / halfCycle)))
        let halfElapsed = loopElapsed - (Double(halfSegment) * halfCycle)
        let halfProgress = CGFloat(halfElapsed / halfCycle)
        let loopDrift = CGFloat(loopIndex) * (2 * (fastTurnsPerHalfCycle + slowTurnsPerHalfCycle))
        let fastProgress = fastTurnsPerHalfCycle * halfProgress
        let slowProgress = slowTurnsPerHalfCycle * halfProgress
        let collisionOne = fastTurnsPerHalfCycle
        let separatedOne = fastTurnsPerHalfCycle + slowTurnsPerHalfCycle
        let collisionTwo = separatedOne + slowTurnsPerHalfCycle

        switch halfSegment {
        case 0:
            return (
                wrapOrbitPhase(loopDrift + fastProgress),
                wrapOrbitPhase(loopDrift + 0.5 + slowProgress)
            )
        case 1:
            return (
                wrapOrbitPhase(loopDrift + collisionOne + slowProgress),
                wrapOrbitPhase(loopDrift + collisionOne + fastProgress)
            )
        case 2:
            return (
                wrapOrbitPhase(loopDrift + separatedOne + slowProgress),
                wrapOrbitPhase(loopDrift + separatedOne + 0.5 + fastProgress)
            )
        default:
            return (
                wrapOrbitPhase(loopDrift + collisionTwo + fastProgress),
                wrapOrbitPhase(loopDrift + collisionTwo + 1 + slowProgress)
            )
        }
    }

    private func wrapOrbitPhase(_ phase: CGFloat) -> CGFloat {
        let wrapped = phase.truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
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
