import BmuxSettings
import BmuxSettingsUI
import Foundation

struct BmuxAppRuntimeComposition {
    private let jsonConfigStore: JSONConfigStore
    private let secretStore: SecretFileStore
    private let keychainStore: KeychainSecretStore
    private let runtimeConfiguration: BmuxAppRuntimeConfiguration

    init(
        configFileURL: URL,
        secretBaseDirectory: URL,
        bundleIdentifier: String?,
        runtimeConfiguration: BmuxAppRuntimeConfiguration
    ) {
        self.jsonConfigStore = JSONConfigStore(fileURL: configFileURL)
        self.secretStore = SecretFileStore(baseDirectory: secretBaseDirectory)
        self.runtimeConfiguration = runtimeConfiguration
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
        guard runtimeConfiguration.enables(.workProvenanceObservation) else {
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
        BmuxAppRuntimeServices(
            configuration: runtimeConfiguration,
            workProvenanceRuntime: workProvenanceRuntime
        )
    }
}
