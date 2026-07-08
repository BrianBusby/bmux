import Foundation

@_spi(BmuxHostTransport)
public enum BmuxExtensionValidationError: Error, Equatable, Sendable {
    case unsupportedAPIVersion(requested: BmuxExtensionAPIVersion, supported: BmuxExtensionAPIVersion)
    case emptyIdentifier
    case emptyDisplayName
    case payloadTooLarge(kind: String, actualBytes: Int, maximumBytes: Int)
}
