import Foundation
import Testing
@testable import BmuxBrowser

@Suite struct BrowserHistoryLocationTests {
    @Test func foldsDebugAndStagingNamespaces() {
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.bmuxterm.app.debug.my-tag") == "com.bmuxterm.app.debug")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.bmuxterm.app.staging.rc") == "com.bmuxterm.app.staging")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.bmuxterm.app") == "com.bmuxterm.app")
    }

    @Test func historyFileURLNestsUnderNamespace() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let location = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.bmuxterm.app.debug.tag")
        #expect(location.namespace == "com.bmuxterm.app.debug")
        #expect(location.historyFileURL.path == "/tmp/appsupport/com.bmuxterm.app.debug/browser_history.json")
    }

    @Test func legacyURLPresentOnlyWhenNamespaceDiffers() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let tagged = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.bmuxterm.app.debug.tag")
        #expect(tagged.legacyTaggedHistoryFileURL?.path == "/tmp/appsupport/com.bmuxterm.app.debug.tag/browser_history.json")

        let prod = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.bmuxterm.app")
        #expect(prod.legacyTaggedHistoryFileURL == nil)
    }
}
