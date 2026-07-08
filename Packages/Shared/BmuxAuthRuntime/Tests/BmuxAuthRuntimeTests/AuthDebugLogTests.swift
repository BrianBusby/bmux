import Foundation
import Testing
@testable import BmuxAuthRuntime

@Suite struct AuthDebugLogTests {
    @Test func debugLogPathsIncludeTaggedDebugLogWhenConfigured() {
        #if DEBUG && os(macOS)
        let paths = AuthDebugLog.debugLogPaths(environment: [
            "BMUX_DEBUG_LOG": "/tmp/bmux-debug-safari.log",
        ])

        #expect(paths == ["/tmp/bmux-auth-debug.log", "/tmp/bmux-debug-safari.log"])
        #endif
    }

    @Test func redactionCoversCallbackTokenQueryValues() {
        let redacted = AuthDebugLog.redacted(
            "auth.callback.complete url=bmux-dev://auth-callback?stack_refresh=refresh-secret&stack_access=access-secret&bmux_auth_state=state-secret"
        )

        #expect(redacted.contains("refresh-secret") == false)
        #expect(redacted.contains("access-secret") == false)
        #expect(redacted.contains("state-secret") == false)
        #expect(redacted.contains("stack_refresh=<redacted>"))
        #expect(redacted.contains("stack_access=<redacted>"))
        #expect(redacted.contains("bmux_auth_state=<redacted>"))
    }

    @Test func redactionCoversEncodedNestedCallbackState() {
        let redacted = AuthDebugLog.redacted(
            "auth.browser.session.create signInURL=http://localhost:4577/handler/native-sign-in?after_auth_return_to=http%3A%2F%2Flocalhost%3A4577%2Fhandler%2Fafter-sign-in%3Fnative_app_return_to%3Dbmux-dev-safauth%253A%252F%252Fauth-callback%253Fbmux_auth_state%253Dstate-secret"
        )

        #expect(redacted.contains("state-secret") == false)
        #expect(redacted.contains("bmux_auth_state%253D<redacted>"))
    }
}
