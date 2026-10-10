import XCTest

extension BrowserPaneNavigationKeybindUITests {
    func launchAndEnsureForeground(_ app: XCUIApplication, timeout: TimeInterval = 12.0) {
        // On headless CI runners (no GUI session), XCUIApplication.launch()
        // blocks ~60s then fails with "Failed to activate application
        // (current state: Running Background)". Mark this as an expected
        // failure so the test can continue — keyboard and element APIs work
        // via accessibility even when the app is in .runningBackground.
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("App activation may fail on headless CI runners", options: options) {
            app.launch()
        }

        if app.state == .runningForeground { return }

        if app.state == .runningBackground {
            // App launched but couldn't activate — continue in background.
            // XCUIElement queries and keyboard input work through the
            // accessibility framework regardless of activation state.
            return
        }

        XCTFail("App failed to start. state=\(app.state.rawValue)")
    }
}
