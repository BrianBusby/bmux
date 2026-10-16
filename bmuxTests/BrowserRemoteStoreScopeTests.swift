import Foundation
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

// Main-actor tests never suspend while profile selection is temporarily owned.
@MainActor
@Suite(.serialized)
struct BrowserRemoteStoreScopeTests {
    @Test(arguments: [false, true])
    func remotePanelsShareWorkspaceStore(explicitDefault: Bool) throws {
        let fixture = try BrowserRemoteStoreFixture(explicitDefault: explicitDefault)
        defer { fixture.close() }
        let local = fixture.panel()
        let workspaceID = UUID()
        let first = fixture.panel(workspaceID: workspaceID, remote: true)
        let second = fixture.panel(workspaceID: workspaceID, remote: true)
        let otherWorkspace = fixture.panel(remote: true)

        #expect(local.profileID == fixture.expectedProfileID)
        #expect(local.webView.configuration.websiteDataStore === fixture.expectedLocalStore)
        #expect(first.webView.configuration.websiteDataStore !== WKWebsiteDataStore.default())
        #expect(first.webView.configuration.websiteDataStore !== fixture.expectedLocalStore)
        #expect(first.webView.configuration.websiteDataStore === second.webView.configuration.websiteDataStore)
        #expect(first.webView.configuration.websiteDataStore !== otherWorkspace.webView.configuration.websiteDataStore)
        #expect([local, first, second, otherWorkspace].allSatisfy { $0.webView.url == nil })
    }

    @Test(arguments: [false, true])
    func movingIntoRemoteWorkspaceRebuildsStoreScope(explicitDefault: Bool) throws {
        let fixture = try BrowserRemoteStoreFixture(explicitDefault: explicitDefault)
        defer { fixture.close() }
        let source = fixture.workspace()
        let browser = try fixture.browser(in: source)
        let localStore = browser.webView.configuration.websiteDataStore
        #expect(localStore === fixture.expectedLocalStore)

        let destination = fixture.workspace(remote: true)
        let existing = try fixture.browser(in: destination)
        let destinationStore = existing.webView.configuration.websiteDataStore
        #expect(destinationStore !== WKWebsiteDataStore.default())
        let moved = try fixture.move(browser, from: source, to: destination)

        #expect(moved.webView.configuration.websiteDataStore === destinationStore)
        #expect(moved.webView.configuration.websiteDataStore !== localStore)
        #expect(existing.webView.configuration.websiteDataStore === destinationStore)
    }

    @Test(arguments: [false, true])
    func movingOutOfRemoteWorkspaceRestoresProfileStore(explicitDefault: Bool) throws {
        let fixture = try BrowserRemoteStoreFixture(explicitDefault: explicitDefault)
        defer { fixture.close() }
        let source = fixture.workspace(remote: true)
        let browser = try fixture.browser(in: source)
        let remaining = try fixture.browser(in: source)
        let remoteStore = remaining.webView.configuration.websiteDataStore
        #expect(remoteStore !== WKWebsiteDataStore.default())
        #expect(browser.webView.configuration.websiteDataStore === remoteStore)

        let destination = fixture.workspace()
        let moved = try fixture.move(browser, from: source, to: destination)
        #expect(moved.webView.configuration.websiteDataStore === fixture.expectedLocalStore)
        #expect(remaining.webView.configuration.websiteDataStore === remoteStore)
        #expect(remaining.webView.configuration.websiteDataStore !== moved.webView.configuration.websiteDataStore)
    }
}
