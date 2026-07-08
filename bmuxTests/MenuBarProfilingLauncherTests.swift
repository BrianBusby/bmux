import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

struct MenuBarProfilingLauncherTests {
    @Test
    func testMenuBarProfilingLaunchesCurrentProcessForFifteenSecondsWithoutOpeningOutput() {
        let arguments = MenuBarProfilingLauncher.arguments(pid: 1234)
        #expect(arguments == ["--pid", "1234", "--duration", "15"])
    }

    @Test
    func testMenuBarProfilingCanDeferSubmissionToProgressWindow() {
        let arguments = MenuBarProfilingLauncher.arguments(pid: 1234, submitProfile: false)
        #expect(arguments == ["--pid", "1234", "--duration", "15", "--no-submit"])
    }

    @Test
    func testMenuBarProfilingEstimatesDefaultCaptureSeconds() {
        #expect(MenuBarProfilingLauncher.estimatedCaptureSeconds() == 60)
    }
}
