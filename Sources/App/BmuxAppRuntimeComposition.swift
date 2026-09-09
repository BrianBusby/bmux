import BmuxSettings
import BmuxSettingsUI
import Foundation

struct BmuxAppRuntimeComposition {
    private let jsonConfigStore: JSONConfigStore
    private let secretStore: SecretFileStore
    private let keychainStore: KeychainSecretStore
    private let runtimeConfiguration: BmuxAppRuntimeConfiguration
    private let mobileHostRuntimeDependencies: MobileHostRuntimeServiceDependencies?
    private let browserDevToolsRuntimeDependencies: BrowserDevToolsRuntimeServiceDependencies?
    private let sidebarGitPullRequestObservationRuntimeDependencies: SidebarGitPullRequestObservationRuntimeServiceDependencies?
    private let notificationPushRuntimeDependencies: NotificationPushRuntimeServiceDependencies?

    init(
        configFileURL: URL,
        secretBaseDirectory: URL,
        bundleIdentifier: String?,
        runtimeConfiguration: BmuxAppRuntimeConfiguration,
        mobileHostRuntimeDependencies: MobileHostRuntimeServiceDependencies? = nil,
        browserDevToolsRuntimeDependencies: BrowserDevToolsRuntimeServiceDependencies? = nil,
        sidebarGitPullRequestObservationRuntimeDependencies: SidebarGitPullRequestObservationRuntimeServiceDependencies? = nil,
        notificationPushRuntimeDependencies: NotificationPushRuntimeServiceDependencies? = nil
    ) {
        self.jsonConfigStore = JSONConfigStore(fileURL: configFileURL)
        self.secretStore = SecretFileStore(baseDirectory: secretBaseDirectory)
        self.runtimeConfiguration = runtimeConfiguration
        self.mobileHostRuntimeDependencies = mobileHostRuntimeDependencies
        self.browserDevToolsRuntimeDependencies = browserDevToolsRuntimeDependencies
        self.sidebarGitPullRequestObservationRuntimeDependencies = sidebarGitPullRequestObservationRuntimeDependencies
        self.notificationPushRuntimeDependencies = notificationPushRuntimeDependencies
        self.keychainStore = KeychainSecretStore(
            service: KeychainSecretStore.serviceName(bundleIdentifier: bundleIdentifier)
        )
    }

    @MainActor
    func makeSettingsRuntime(
        catalog: SettingCatalog,
        authComposition: MacAuthComposition,
        configFileURL: URL
    ) -> SettingsRuntime {
        SettingsRuntime(
            catalog: catalog,
            userDefaultsStore: UserDefaultsSettingsStore(
                defaults: .standard,
                migrating: catalog.all
            ),
            jsonStore: jsonConfigStore,
            secretStore: secretStore,
            keychainStore: keychainStore,
            errorLog: SettingsErrorLog(),
            accountFlow: HostAccountFlow(
                coordinator: authComposition.coordinator,
                browserSignIn: authComposition.browserSignIn
            ),
            hostActions: HostSettingsActions(configFileURL: configFileURL)
        )
    }

    func linearAuthorizationProvider(
        catalog: SettingCatalog
    ) -> any WorkProvenanceLinearAuthorizationProviding {
        WorkProvenanceCompositeLinearAuthorizationProvider([
            WorkProvenanceEnvironmentLinearAuthorizationProvider(),
            WorkProvenanceSettingsLinearAuthorizationProvider(
                keychainStore: keychainStore,
                jsonStore: jsonConfigStore,
                catalog: catalog
            ),
        ])
    }

    @MainActor
    func makeWorkProvenanceRuntime(catalog: SettingCatalog) -> WorkProvenanceRuntime {
        let requiresWorkProvenanceStorage = runtimeConfiguration.enables(.workProvenanceObservation)
            || runtimeConfiguration.enables(.agentChatExecutionTelemetryProjection)
        guard requiresWorkProvenanceStorage else {
            return WorkProvenanceRuntime.disabledByComposition()
        }
        return WorkProvenanceRuntime.live(
            homeDirectory: runtimeConfiguration.workProvenanceHomeDirectory,
            linearAuthorizationProvider: linearAuthorizationProvider(catalog: catalog)
        )
    }

    @MainActor
    func makeRuntimeServices(
        workProvenanceRuntime: WorkProvenanceRuntime
    ) -> BmuxAppRuntimeServices {
        let mobileHostRuntimeService = MobileHostRuntimeService(
            isCapabilityEnabled: runtimeConfiguration.enables(.mobileHostAndPresence),
            dependencies: mobileHostRuntimeDependencies ?? .production()
        )
        let browserDevToolsRuntimeService = BrowserDevToolsRuntimeService(
            isCapabilityEnabled: runtimeConfiguration.enables(.browserAndDevTools),
            dependencies: browserDevToolsRuntimeDependencies ?? .production()
        )
        let sidebarGitPullRequestObservationRuntimeService = SidebarGitPullRequestObservationRuntimeService(
            isCapabilityEnabled: runtimeConfiguration.enables(.sidebarGitPullRequestObservation),
            dependencies: sidebarGitPullRequestObservationRuntimeDependencies ?? .production()
        )
        let notificationPushRuntimeService = NotificationPushRuntimeService(
            isCapabilityEnabled: runtimeConfiguration.enables(.notificationPushLifecycle),
            dependencies: notificationPushRuntimeDependencies ?? .production()
        )
        return BmuxAppRuntimeServices(
            configuration: runtimeConfiguration,
            workProvenanceRuntime: workProvenanceRuntime,
            mobileHostRuntimeService: mobileHostRuntimeService,
            browserDevToolsRuntimeService: browserDevToolsRuntimeService,
            sidebarGitPullRequestObservationRuntimeService: sidebarGitPullRequestObservationRuntimeService,
            notificationPushRuntimeService: notificationPushRuntimeService
        )
    }
}
