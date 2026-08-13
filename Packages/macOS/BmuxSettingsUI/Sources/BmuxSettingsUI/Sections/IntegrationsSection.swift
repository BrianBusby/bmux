import BmuxSettings
import SwiftUI

/// **Integrations** section for provider credentials and external service hooks.
@MainActor
public struct IntegrationsSection: View {
    private let catalog: SettingCatalog

    @State private var linearAPIKeyModel: KeychainSecretValueModel
    @State private var linearAPIKeyDraft: String = ""

    /// Creates the integrations section with stores supplied by the host app.
    ///
    /// - Parameters:
    ///   - keychainStore: Store used for provider credentials that must not live in `bmux.json`.
    ///   - catalog: Immutable settings catalog that declares integration keys.
    ///   - errorLog: Shared Settings error log for surfacing write failures.
    public init(
        keychainStore: KeychainSecretStore,
        catalog: SettingCatalog,
        errorLog: SettingsErrorLog
    ) {
        self.catalog = catalog
        _linearAPIKeyModel = State(initialValue: KeychainSecretValueModel(
            store: keychainStore,
            key: catalog.integrations.linearAPIKey,
            errorLog: errorLog
        ))
    }

    public var body: some View {
        Group {
            SettingsSectionHeader(
                String(localized: "settings.section.integrations", defaultValue: "Integrations"),
                section: .integrations
            )

            SettingsCard {
                linearTicketTitlesRow
                SettingsCardDivider()
                SettingsCardNote(String(
                    localized: "settings.integrations.linear.note",
                    defaultValue: "bmux uses this credential only to fetch Linear issue titles for workspace provenance. For headless setups, set integrations.linear.authorizationHeader in bmux.json."
                ))
            }
        }
        .task { startSettingsObservation([linearAPIKeyModel]) }
    }

    private var linearTicketTitlesRow: some View {
        let hasAPIKey = !linearAPIKeyModel.current.isEmpty
        return SettingsCardRow(
            configurationReview: .settingsOnly,
            searchAnchorID: "setting:integrations:linear-api-key",
            String(localized: "settings.integrations.linear.apiKey", defaultValue: "Linear API Key"),
            subtitle: hasAPIKey
                ? String(localized: "settings.integrations.linear.apiKey.subtitleSet", defaultValue: "Stored in Keychain.")
                : String(localized: "settings.integrations.linear.apiKey.subtitleUnset", defaultValue: "No API key set. Ticket IDs still persist, but titles require a Linear token.")
        ) {
            HStack(spacing: 8) {
                SecureField(
                    String(localized: "settings.integrations.linear.apiKey.placeholder", defaultValue: "API key"),
                    text: $linearAPIKeyDraft
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 170)

                Button(
                    hasAPIKey
                        ? String(localized: "settings.integrations.linear.apiKey.update", defaultValue: "Update")
                        : String(localized: "settings.integrations.linear.apiKey.save", defaultValue: "Save")
                ) {
                    saveLinearAPIKey()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(linearAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasAPIKey {
                    Button(String(localized: "settings.integrations.linear.apiKey.clear", defaultValue: "Clear")) {
                        clearLinearAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func saveLinearAPIKey() {
        let trimmed = linearAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        linearAPIKeyModel.set(trimmed)
        linearAPIKeyDraft = ""
    }

    private func clearLinearAPIKey() {
        linearAPIKeyModel.reset()
        linearAPIKeyDraft = ""
    }
}
