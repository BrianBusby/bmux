import BmuxBrowser
import BmuxCore
import Foundation
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns profile selection and unmounted panels for a synchronous store-scope test.
@MainActor
final class BrowserRemoteStoreFixture {
    let requestedProfileID: UUID?
    let expectedProfileID: UUID
    let expectedLocalStore: WKWebsiteDataStore
    private let profiles = BrowserProfileStore.shared
    private let previousProfileID: UUID
    private let previousProfiles: Any?
    private let previousUsed: Any?
    private let namedProfileID: UUID
    private var panels: [UUID: any Panel] = [:]
    private var workspaces: [Workspace] = []

    init(explicitDefault: Bool) throws {
        previousProfileID = profiles.lastUsedProfileID
        previousProfiles = UserDefaults.standard.object(forKey: BrowserProfileRepository.profilesDefaultsKey)
        previousUsed = UserDefaults.standard.object(forKey: BrowserProfileRepository.lastUsedProfileDefaultsKey)
        namedProfileID = try #require(profiles.createProfile(named: "Roof Inspection")).id
        requestedProfileID = explicitDefault ? profiles.builtInDefaultProfileID : nil
        expectedProfileID = explicitDefault ? profiles.builtInDefaultProfileID : namedProfileID
        expectedLocalStore = profiles.websiteDataStore(for: expectedProfileID)
        #expect((expectedLocalStore === WKWebsiteDataStore.default()) == explicitDefault)
    }

    func close() {
        for panel in panels.values { panel.close() }
        panels.removeAll()
        workspaces.removeAll()
        profiles.noteUsed(previousProfileID)
        _ = profiles.deleteProfile(id: namedProfileID)
        UserDefaults.standard.set(previousProfiles, forKey: BrowserProfileRepository.profilesDefaultsKey)
        UserDefaults.standard.set(previousUsed, forKey: BrowserProfileRepository.lastUsedProfileDefaultsKey)
    }

    func panel(workspaceID: UUID = UUID(), remote: Bool = false) -> BrowserPanel {
        let panel = BrowserPanel(
            workspaceId: workspaceID, profileID: requestedProfileID,
            isRemoteWorkspace: remote,
            remoteWebsiteDataStoreIdentifier: remote ? workspaceID : nil
        )
        panels[panel.id] = panel
        return panel
    }

    func workspace(remote: Bool = false) -> Workspace {
        let workspace = Workspace()
        workspaces.append(workspace)
        for panel in workspace.panels.values { panels[panel.id] = panel }
        if remote {
            workspace.configureRemoteConnection(
                WorkspaceRemoteConfiguration(
                    destination: "bmux-macmini", port: 22, identityFile: nil, sshOptions: [],
                    localProxyPort: nil, relayPort: 64001, relayID: "relay-store-scope",
                    relayToken: String(repeating: "a", count: 64),
                    localSocketPath: "/tmp/bmux-store-scope-\(workspace.id).sock",
                    terminalStartupCommand: "ssh bmux-macmini"
                ),
                autoConnect: false
            )
            #expect(workspace.remotePTYSessionControllerForSocketCommand() == nil)
        }
        return workspace
    }

    func browser(in workspace: Workspace) throws -> BrowserPanel {
        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        let browser = try #require(workspace.newBrowserSurface(
            inPane: pane, focus: false, preferredProfileID: requestedProfileID
        ))
        panels[browser.id] = browser
        #expect(browser.profileID == expectedProfileID)
        #expect(browser.webView.url == nil)
        return browser
    }

    func move(_ browser: BrowserPanel, from source: Workspace, to destination: Workspace) throws -> BrowserPanel {
        let pane = try #require(destination.bonsplitController.allPaneIds.first)
        let detached = try #require(source.detachSurface(panelId: browser.id))
        let attachedID = try #require(destination.attachDetachedSurface(detached, inPane: pane, focus: false))
        let attached = try #require(destination.panels[attachedID] as? BrowserPanel)
        #expect(attached === browser)
        #expect(attachedID == browser.id)
        #expect(source.panels[browser.id] == nil)
        #expect(attached.workspaceId == destination.id)
        #expect(attached.profileID == expectedProfileID)
        #expect(attached.webView.url == nil)
        return attached
    }
}
