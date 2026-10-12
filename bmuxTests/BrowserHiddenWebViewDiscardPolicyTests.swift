import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

struct BrowserHiddenWebViewDiscardPolicyTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BMUX_BROWSER_HIDDEN_WEBVIEW_DISCARD_ENABLED"] == nil))
    func enabledPreferenceUsesDefaultAndStoredValue() throws {
        try withDefaults { defaults in
            #expect(BrowserHiddenWebViewDiscardPolicy.isEnabled(defaults: defaults) == BrowserHiddenWebViewDiscardPolicy.defaultEnabled)
            for enabled in [false, true] {
                defaults.set(enabled, forKey: BrowserHiddenWebViewDiscardPolicy.enabledKey)
                #expect(BrowserHiddenWebViewDiscardPolicy.isEnabled(defaults: defaults) == enabled)
            }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BMUX_BROWSER_HIDDEN_WEBVIEW_DISCARD_DELAY_SECONDS"] == nil))
    func missingDelayUsesDefault() throws {
        try withDefaults { defaults in
            #expect(BrowserHiddenWebViewDiscardPolicy.hiddenDelay(defaults: defaults) == BrowserHiddenWebViewDiscardPolicy.defaultHiddenDelay)
        }
    }

    @Test(
        .enabled(if: ProcessInfo.processInfo.environment["BMUX_BROWSER_HIDDEN_WEBVIEW_DISCARD_DELAY_SECONDS"] == nil),
        arguments: [(0.0, 0.0), (42.5, 42.5), (3600.0, 3600.0), (-1.0, 300.0), (3601.0, 300.0), (7200.0, 300.0)]
    )
    func storedDelayAcceptsSupportedValuesAndRejectsOutOfRange(value: Double, expected: Double) throws {
        try withDefaults { defaults in
            defaults.set(value, forKey: BrowserHiddenWebViewDiscardPolicy.hiddenDelayKey)
            #expect(BrowserHiddenWebViewDiscardPolicy.hiddenDelay(defaults: defaults) == expected)
            #expect(defaults.double(forKey: BrowserHiddenWebViewDiscardPolicy.hiddenDelayKey) == value)
        }
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, -1.0, 3601.0, 7200.0])
    func invalidDelayIsRejected(value: Double) {
        #expect(BrowserHiddenWebViewDiscardPolicy.resolvedHiddenDelay(value) == nil)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "com.bmux.BrowserHiddenWebViewDiscardPolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }
}
