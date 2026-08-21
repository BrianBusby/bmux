import Foundation
import BmuxBrowser
import BmuxCore

extension BrowserPanel {
    static func restorableDisplayURL(
        liveURL: URL?,
        currentURL: URL?,
        activeErrorPageDisplayURL: URL?
    ) -> URL? {
        restorableDisplayURLCandidate(for: activeErrorPageDisplayURL)
            ?? restorableDisplayURLCandidate(for: liveURL)
            ?? restorableDisplayURLCandidate(for: currentURL)
    }

    private static func restorableDisplayURLCandidate(for url: URL?) -> URL? {
        let displayURL = remoteProxyDisplayURL(for: url) ?? url
        guard !isBlankBrowserPageURL(displayURL) else { return nil }
        return displayURL
    }

    static func remoteProxyDisplayURL(for url: URL?) -> URL? {
        guard let url else { return nil }
        guard let host = BrowserInsecureHTTPSettings.normalizeHost(url.host ?? "") else { return url }
        guard let displayHost = RemoteLoopbackProxyAlias.localhostFamilyHost(
            forAliasHost: host,
            aliasHost: RemoteLoopbackProxyAlias.aliasHost
        ) else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = displayHost
        return components?.url ?? url
    }

    /// Returns the most reliable URL string for omnibar-related matching and UI decisions.
    /// `currentURL` can lag behind navigation changes, so prefer the live WKWebView URL.
    func preferredURLStringForOmnibar() -> String? {
        if let webViewURL = restorableDisplayURLForCurrentErrorPage(liveURL: webView.url)?.absoluteString
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !webViewURL.isEmpty,
           webViewURL != blankURLString {
            return webViewURL
        }

        if let current = currentURL?.absoluteString
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !current.isEmpty,
           current != blankURLString {
            return current
        }

        return nil
    }

    func resolvedCurrentSessionHistoryURL() -> URL? {
        if let displayURL = restorableDisplayURLForCurrentErrorPage(liveURL: webView.url),
           Self.serializableSessionHistoryURLString(displayURL) != nil {
            return displayURL
        }
        if let currentURL,
           Self.serializableSessionHistoryURLString(currentURL) != nil {
            return currentURL
        }
        return restoredHistoryCurrentURL
    }

    var cancellableProvisionalForwardURL: URL? {
        guard isMainFrameProvisionalNavigationActive || pendingMainFrameNavigationURL != nil else { return nil }
        guard let attemptedURL = pendingMainFrameNavigationURL ?? navigationDelegate?.lastAttemptedURL,
              let attemptedURLString = Self.serializableSessionHistoryURLString(attemptedURL),
              let currentURLString = Self.serializableSessionHistoryURLString(currentURL ?? restoredHistoryCurrentURL),
              attemptedURLString != currentURLString else {
            return nil
        }
        return attemptedURL
    }

    /// Shared sanitizer mirroring the restored-session-history URL rules, used by
    /// the surface's WebKit-touching resolution helpers.
    private static let sessionHistoryURLSanitizer = SessionHistoryURLSanitizer {
        browserIsTemporaryHistoryURL($0)
    }

    static func serializableSessionHistoryURLString(_ url: URL?) -> String? {
        sessionHistoryURLSanitizer.serializableSessionHistoryURLString(url)
    }

    static func sanitizedSessionHistoryURL(_ raw: String?) -> URL? {
        sessionHistoryURLSanitizer.sanitizedSessionHistoryURL(raw)
    }

    static func sanitizedSessionHistoryURLs(_ values: [String]) -> [URL] {
        sessionHistoryURLSanitizer.sanitizedSessionHistoryURLs(values)
    }

    static func isTemporarySessionHistoryURL(_ url: URL?) -> Bool {
        sessionHistoryURLSanitizer.isTemporarySessionHistoryURL(url)
    }
}
