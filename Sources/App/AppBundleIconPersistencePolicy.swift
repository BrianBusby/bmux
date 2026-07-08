import Foundation

enum AppBundleIconPersistencePolicy {
    private static let stableReleaseBundleIdentifier = "com.bmuxterm.app"
    private static let stableReleaseAppBundleName = "bmux.app"
    static let disablePersistenceArgument = "--bmux-disable-bundle-icon-persistence"
    static let disablePersistenceDefaultsKey = "bmuxDisableBundleIconPersistence"

    static func updateDisableDefault(defaults: UserDefaults, launchArguments: [String]) {
        defaults.set(
            launchArguments.contains(disablePersistenceArgument),
            forKey: disablePersistenceDefaultsKey
        )
    }

    static func shouldPersist(
        bundleIdentifier: String?,
        appBundleLastPathComponent: String?,
        persistenceDisabled: Bool = false
    ) -> Bool {
        guard !persistenceDisabled else {
            return false
        }

        // Channel variants own their identity through build-time bundle metadata.
        // Persisted Finder icons would override that metadata and can leak into
        // packaged artifacts after CI smoke launches the app bundle.
        return bundleIdentifier == stableReleaseBundleIdentifier
            && appBundleLastPathComponent == stableReleaseAppBundleName
    }
}
