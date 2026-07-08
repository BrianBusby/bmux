import BMUXAuthCore
import Testing
@testable import BmuxAuthRuntime

@Suite struct AuthConfigTests {
    @Test func productionUsesStackWhitelistedBmuxDomain() {
        let config = AuthConfig(environment: .production)

        #expect(config.magicLinkCallbackURL == "https://bmux.com/auth/callback")
        #expect(config.apiBaseURL == "https://bmux.com")
    }
}
