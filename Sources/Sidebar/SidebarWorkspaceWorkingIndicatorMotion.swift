import SwiftUI

struct SidebarWorkspaceWorkingIndicatorMotion {
    var handoffPeriod: TimeInterval = 1.5
    var slowTurnsPerHalfCycle: CGFloat = 0.16
    var contactSeparationTurns: CGFloat = 0

    static func workspaceTabSize(forBadgeSize badgeSize: CGFloat) -> CGFloat {
        max(badgeSize + 2, badgeSize * 1.125)
    }

    func phases(atElapsedTime elapsed: TimeInterval) -> (first: CGFloat, second: CGFloat) {
        let halfCycle = handoffPeriod * 0.5
        let fullLoop = handoffPeriod * 2
        let loopIndex = floor(elapsed / fullLoop)
        let loopElapsed = elapsed - (loopIndex * fullLoop)
        let halfSegment = min(3, Int(floor(loopElapsed / halfCycle)))
        let halfElapsed = loopElapsed - (Double(halfSegment) * halfCycle)
        let halfProgress = CGFloat(halfElapsed / halfCycle)
        let loopDrift = CGFloat(loopIndex) * (2 * (fastTurnsPerHalfCycle + slowTurnsPerHalfCycle))
        let fastProgress = fastTurnsPerHalfCycle * halfProgress
        let slowProgress = slowTurnsPerHalfCycle * halfProgress
        let firstContactFirstPhase = fastTurnsPerHalfCycle
        let firstSeparatedPhase = fastTurnsPerHalfCycle + slowTurnsPerHalfCycle
        let secondContactFirstPhase = fastTurnsPerHalfCycle + (2 * slowTurnsPerHalfCycle)

        switch halfSegment {
        case 0:
            return (
                wrapPhase(loopDrift + fastProgress),
                wrapPhase(loopDrift + 0.5 + slowProgress)
            )
        case 1:
            return (
                wrapPhase(loopDrift + firstContactFirstPhase + slowProgress),
                wrapPhase(loopDrift + firstContactFirstPhase + contactSeparationTurns + fastProgress)
            )
        case 2:
            return (
                wrapPhase(loopDrift + firstSeparatedPhase + slowProgress),
                wrapPhase(loopDrift + firstSeparatedPhase + 0.5 + fastProgress)
            )
        default:
            return (
                wrapPhase(loopDrift + secondContactFirstPhase + fastProgress),
                wrapPhase(loopDrift + secondContactFirstPhase + 1 - contactSeparationTurns + slowProgress)
            )
        }
    }

    func phaseSeparation(atElapsedTime elapsed: TimeInterval) -> CGFloat {
        let phases = phases(atElapsedTime: elapsed)
        return forwardDistance(from: phases.first, to: phases.second)
    }

    func forwardDistance(from start: CGFloat, to end: CGFloat) -> CGFloat {
        let distance = (end - start).truncatingRemainder(dividingBy: 1)
        return distance >= 0 ? distance : distance + 1
    }

    private var fastTurnsPerHalfCycle: CGFloat {
        slowTurnsPerHalfCycle + max(0.2, 0.5 - contactSeparationTurns)
    }

    private func wrapPhase(_ phase: CGFloat) -> CGFloat {
        let wrapped = phase.truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
    }
}
