import Foundation

/// Validates a sidebar extension manifest before BMUX trusts it.
@_spi(BmuxHostTransport)
public func validateSidebarManifest(
    _ manifest: BmuxExtensionManifest,
    supportedAPIVersion: BmuxExtensionAPIVersion = .sidebarV2
) throws {
    guard manifest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw BmuxExtensionValidationError.emptyIdentifier
    }
    guard manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw BmuxExtensionValidationError.emptyDisplayName
    }
    guard manifest.minimumAPIVersion.major == supportedAPIVersion.major,
          manifest.minimumAPIVersion <= supportedAPIVersion else {
        throw BmuxExtensionValidationError.unsupportedAPIVersion(
            requested: manifest.minimumAPIVersion,
            supported: supportedAPIVersion
        )
    }
}
