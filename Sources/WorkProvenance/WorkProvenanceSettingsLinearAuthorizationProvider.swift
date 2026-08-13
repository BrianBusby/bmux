import BmuxSettings
import Foundation

/// Reads Linear credentials from bmux Settings stores.
struct WorkProvenanceSettingsLinearAuthorizationProvider: WorkProvenanceLinearAuthorizationProviding {
    private let keychainStore: KeychainSecretStore
    private let jsonStore: JSONConfigStore
    private let catalog: SettingCatalog

    init(
        keychainStore: KeychainSecretStore,
        jsonStore: JSONConfigStore,
        catalog: SettingCatalog
    ) {
        self.keychainStore = keychainStore
        self.jsonStore = jsonStore
        self.catalog = catalog
    }

    func authorizationHeader() async -> String? {
        if let apiKey = try? await keychainStore.value(for: catalog.integrations.linearAPIKey),
           let normalizedAPIKey = Self.normalizedNonEmpty(apiKey) {
            return normalizedAPIKey
        }
        let configuredHeader = jsonStore.snapshotValue(for: catalog.integrations.linearAuthorizationHeader)
        return Self.normalizedNonEmpty(configuredHeader)
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
