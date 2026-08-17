import CoreGraphics
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct SidebarWorkspaceWorkingBorderMotionTests {
    @Test
    func advancesStripeOffset() {
        let motion = SidebarWorkspaceWorkingBorderMotion(stripePeriod: 2, stripeTravel: 40)

        #expect(abs(motion.stripeOffset(atElapsedTime: 0) - 0) < 0.001)
        #expect(abs(motion.stripeOffset(atElapsedTime: 0.5) - 10) < 0.001)
        #expect(abs(motion.stripeOffset(atElapsedTime: 1.0) - 20) < 0.001)
        #expect(abs(motion.stripeOffset(atElapsedTime: 1.5) - 30) < 0.001)
    }

    @Test
    func wrapsAtPatternBoundary() {
        let motion = SidebarWorkspaceWorkingBorderMotion(stripePeriod: 2, stripeTravel: 40)

        #expect(abs(motion.stripeOffset(atElapsedTime: 2) - 0) < 0.001)
        #expect(abs(motion.stripeOffset(atElapsedTime: 2.25) - 5) < 0.001)
        #expect(abs(motion.stripeOffset(atElapsedTime: -0.5) - 30) < 0.001)
    }

    @Test
    func stopsForInvalidPeriodsOrTravel() {
        #expect(
            abs(SidebarWorkspaceWorkingBorderMotion(
                stripePeriod: 0,
                stripeTravel: 40
            ).stripeOffset(atElapsedTime: 1) - 0) < 0.001
        )
        #expect(
            abs(SidebarWorkspaceWorkingBorderMotion(
                stripePeriod: 2,
                stripeTravel: 0
            ).stripeOffset(atElapsedTime: 1) - 0) < 0.001
        )
    }
}
