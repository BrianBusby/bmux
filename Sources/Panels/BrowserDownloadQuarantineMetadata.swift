import CoreServices
import Foundation

/// The exact quarantine metadata submitted to LaunchServices, whose readback may omit URLs.
nonisolated struct BrowserDownloadQuarantineMetadata: Sendable {
    let sourceURL: URL?
    let agentName: String
    let agentBundleIdentifier: String?
    let timestamp: Date

    init(sourceURL: URL, agentName: String, agentBundleIdentifier: String?, timestamp: Date) {
        self.sourceURL = Self.sanitizedSourceURL(sourceURL)
        self.agentName = agentName
        self.agentBundleIdentifier = agentBundleIdentifier
        self.timestamp = timestamp
    }

    var resourceValues: URLResourceValues {
        var properties: [String: Any] = [
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload as String,
            kLSQuarantineTimeStampKey as String: timestamp,
            kLSQuarantineAgentNameKey as String: agentName,
        ]
        if let agentBundleIdentifier, !agentBundleIdentifier.isEmpty {
            properties[kLSQuarantineAgentBundleIdentifierKey as String] = agentBundleIdentifier
        }
        if let sourceURL {
            properties[kLSQuarantineDataURLKey as String] = sourceURL
            properties[kLSQuarantineOriginURLKey as String] = sourceURL
        }
        var values = URLResourceValues()
        values.quarantineProperties = properties
        return values
    }

    private static func sanitizedSourceURL(_ sourceURL: URL) -> URL? {
        let scheme = sourceURL.scheme?.lowercased()
        guard scheme == "http" || scheme == "https",
              var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
