import SwiftUI

/// Recovery actions for missing Provenance Engine facts in Explorer.
@MainActor
struct WorkspaceExplorerProvenanceNotice: View {
    @State private var restartFailed = false

    let startupFailed: Bool
    let partialLiveActivity: Bool
    let restartApp: @MainActor () throws -> Void
    let onRetry: () -> Void

    var body: some View {
        if startupFailed {
            HStack(spacing: 8) {
                Text(String(localized: "explorer.provenanceUnavailable", defaultValue:
                    "Provenance Engine could not start. Repository and activity details may be missing."))
                Spacer()
                Button(String(localized: "explorer.restartBmux", defaultValue: "Restart bmux")) {
                    do { try restartApp() } catch { restartFailed = true }
                }
            }
            .font(.system(size: 12)).padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
        }
        if restartFailed {
            Text(String(localized: "explorer.restartFailed", defaultValue:
                "bmux could not restart. Quit and reopen the app to retry Provenance Engine."))
                .font(.system(size: 12)).padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        if !startupFailed && partialLiveActivity {
            HStack(spacing: 8) {
                Text(String(localized: "explorer.partialActivity", defaultValue:
                    "Some live activity could not be verified. Time filters may omit those workspaces."))
                Spacer()
                Button(String(localized: "explorer.retry", defaultValue: "Retry"), action: onRetry)
            }
            .font(.system(size: 12)).padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
