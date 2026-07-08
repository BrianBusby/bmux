import BMUXAuthCore
import Foundation
import Testing

@Suite("BMUXAuthCore")
struct BMUXAuthStateTests {
    @Test("Config resolves development defaults and overrides")
    func configResolvesDevelopmentDefaultsAndOverrides() {
        let defaults = BMUXAuthConfig(
            environment: .development,
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(defaults == BMUXAuthConfig(projectId: "dev-project", publishableClientKey: "dev-key"))

        let overrides = BMUXAuthConfig(
            environment: .development,
            overrides: [
                "STACK_PROJECT_ID_DEV": "override-project",
                "STACK_PUBLISHABLE_CLIENT_KEY_DEV": "override-key",
            ],
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(overrides == BMUXAuthConfig(projectId: "override-project", publishableClientKey: "override-key"))
    }

    @Test("Config resolves production defaults and overrides")
    func configResolvesProductionDefaultsAndOverrides() {
        let defaults = BMUXAuthConfig(
            environment: .production,
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(defaults == BMUXAuthConfig(projectId: "prod-project", publishableClientKey: "prod-key"))

        let overrides = BMUXAuthConfig(
            environment: .production,
            overrides: [
                "STACK_PROJECT_ID_PROD": "override-project",
                "STACK_PUBLISHABLE_CLIENT_KEY_PROD": "override-key",
            ],
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(overrides == BMUXAuthConfig(projectId: "override-project", publishableClientKey: "override-key"))
    }

    @Test("Launch config returns credentials only when enabled")
    func launchConfigReturnsCredentialsOnlyWhenEnabled() {
        let environment = [
            "BMUX_UITEST_STACK_EMAIL": "test@example.com",
            "BMUX_UITEST_STACK_PASSWORD": "pass123",
        ]

        #expect(
            BMUXAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: false,
                mockDataEnabled: false
            ) == BMUXAuthAutoLoginCredentials(email: "test@example.com", password: "pass123")
        )
        #expect(
            BMUXAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: true,
                mockDataEnabled: false
            ) == nil
        )
        #expect(
            BMUXAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: false,
                mockDataEnabled: true
            ) == nil
        )
    }

    @Test("Launch config returns fixture user only when enabled")
    func launchConfigReturnsFixtureUserOnlyWhenEnabled() {
        let environment = [
            "BMUX_UITEST_AUTH_FIXTURE": "1",
            "BMUX_UITEST_AUTH_USER_ID": "fixture-user",
            "BMUX_UITEST_AUTH_EMAIL": "fixture@example.com",
            "BMUX_UITEST_AUTH_NAME": "Fixture User",
        ]

        #expect(
            BMUXAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: false,
                mockDataEnabled: false
            ) == BMUXAuthUser(
                id: "fixture-user",
                primaryEmail: "fixture@example.com",
                displayName: "Fixture User"
            )
        )
        #expect(
            BMUXAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: true,
                mockDataEnabled: false
            ) == nil
        )
        #expect(
            BMUXAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: false,
                mockDataEnabled: true
            ) == nil
        )
    }

    @Test("Primed state authenticates cached user while validating tokens")
    func primedStateAuthenticatesCachedUserWhileValidatingTokens() {
        let user = BMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = BMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: user,
            hasTokens: true,
            mockUser: BMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(!state.isRestoringSession)
    }

    @Test("Primed state restores when tokens exist without a cached user")
    func primedStateRestoresWhenTokensExistWithoutCachedUser() {
        let state = BMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: nil,
            hasTokens: true,
            mockUser: BMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == nil)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state does not authenticate from auto-login credentials before sign-in")
    func primedStateDoesNotAuthenticateFromAutoLoginCredentialsBeforeSignIn() {
        let user = BMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = BMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: BMUXAuthAutoLoginCredentials(email: "user@example.com", password: "password"),
            cachedUser: user,
            hasTokens: false,
            mockUser: BMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state ignores auto-login credentials when cached tokens exist")
    func primedStateIgnoresAutoLoginCredentialsWhenCachedTokensExist() {
        let user = BMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = BMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: BMUXAuthAutoLoginCredentials(email: "user@example.com", password: "password"),
            cachedUser: user,
            hasTokens: true,
            mockUser: BMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(!state.isRestoringSession)
    }

    @Test("Primed state does not authenticate from cached user alone")
    func primedStateDoesNotAuthenticateFromCachedUserAlone() {
        let user = BMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = BMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: user,
            hasTokens: false,
            mockUser: BMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(!state.isRestoringSession)
    }

    @Test("Primed state uses fixture user")
    func primedStateUsesFixtureUser() {
        let fixtureUser = BMUXAuthUser(id: "fixture", primaryEmail: "fixture@example.com", displayName: "Fixture")
        let state = BMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: fixtureUser,
            autoLoginCredentials: nil,
            cachedUser: nil,
            hasTokens: false,
            mockUser: BMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == fixtureUser)
        #expect(!state.isRestoringSession)
    }

    @Test("Cleared state clears auth")
    func clearedStateClearsAuth() {
        #expect(BMUXAuthState.cleared() == BMUXAuthState(isAuthenticated: false, currentUser: nil, isRestoringSession: false))
    }

    @Test("Identity store and session cache round trip")
    func identityStoreAndSessionCacheRoundTrip() throws {
        let store = TestKeyValueStore()
        let identityStore = BMUXAuthIdentityStore(keyValueStore: store, key: "auth_cached_user")
        let sessionCache = BMUXAuthSessionCache(keyValueStore: store, key: "auth_has_tokens")
        let user = BMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")

        try identityStore.save(user)
        #expect(try identityStore.load() == user)

        sessionCache.setHasTokens(true)
        #expect(sessionCache.hasTokens)

        identityStore.clear()
        sessionCache.clear()

        #expect(try identityStore.load() == nil)
        #expect(!sessionCache.hasTokens)
    }
}

private final class TestKeyValueStore: BMUXAuthKeyValueStore {
    private var storage: [String: Any] = [:]

    func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}
