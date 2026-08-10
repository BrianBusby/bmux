import AppKit

struct BrowserExternalLinkOpener {
    typealias ChromeApplicationURLProvider = () -> URL?
    typealias ChromeURLOpener = ([URL], URL, NSWorkspace.OpenConfiguration) -> Void
    typealias SystemURLOpener = (URL) -> Bool

    static let chromeBundleIdentifier = "com.google.Chrome"

    private let chromeApplicationURL: ChromeApplicationURLProvider
    private let openURLsInChrome: ChromeURLOpener
    private let openURLWithSystemHandler: SystemURLOpener

    init(
        chromeApplicationURL: @escaping ChromeApplicationURLProvider = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.chromeBundleIdentifier)
        },
        openURLsInChrome: @escaping ChromeURLOpener = { urls, applicationURL, configuration in
            NSWorkspace.shared.open(
                urls,
                withApplicationAt: applicationURL,
                configuration: configuration
            )
        },
        openURLWithSystemHandler: @escaping SystemURLOpener = { url in
            NSWorkspace.shared.open(url)
        }
    ) {
        self.chromeApplicationURL = chromeApplicationURL
        self.openURLsInChrome = openURLsInChrome
        self.openURLWithSystemHandler = openURLWithSystemHandler
    }

    @discardableResult
    func openWebLink(_ url: URL) -> Bool {
        guard isWebLink(url) else {
            return openURLWithSystemHandler(url)
        }
        guard let chromeURL = chromeApplicationURL() else {
            return openURLWithSystemHandler(url)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        openURLsInChrome([url], chromeURL, configuration)
        return true
    }

    func isWebLink(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }
}
