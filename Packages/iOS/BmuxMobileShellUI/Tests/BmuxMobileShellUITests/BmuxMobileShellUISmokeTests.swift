import Testing
@testable import BmuxMobileShellUI

/// BmuxMobileShellUI is UIKit-bound and iOS-only; its behavior is exercised by
/// the app build and the lower-layer packages' suites. This smoke test keeps the
/// test target valid for simulator-destination CI runs.
@Suite struct BmuxMobileShellUISmokeTests {
    @Test func moduleLinks() {
        #expect(Bool(true))
    }
}
