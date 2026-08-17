import CoreGraphics
import Foundation

struct SidebarWorkspaceWorkingBorderMotion: Equatable {
    var stripePeriod: TimeInterval = 1.35
    var stripeTravel: CGFloat = 44

    func stripeOffset(atElapsedTime elapsed: TimeInterval) -> CGFloat {
        guard stripePeriod > 0, stripeTravel > 0 else { return 0 }

        let cycleProgress = elapsed
            .truncatingRemainder(dividingBy: stripePeriod)
            / stripePeriod
        let normalizedProgress = cycleProgress >= 0 ? cycleProgress : cycleProgress + 1
        return CGFloat(normalizedProgress) * stripeTravel
    }
}
