import Foundation
import Testing
import BmuxSettings

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct WorkspaceSplitTitleDeliveryTests {
    @Test func focusedPanelTitleRefreshesAutoWorkspaceTitleInSplitWorkspace() throws {
        let suiteName = "bmux-split-title-delivery-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = UserDefaultsSettingsClient(defaults: defaults)
        settings.set(false, for: SettingCatalog().terminal.titleUpdateCoalescingEnabled)
        // Retain the imported owner's callback type across Swift language modes.
        var scheduled: NotificationBurstCoalescer.Cancellation?
        var delays: [TimeInterval] = []
        let coalescer = NotificationBurstCoalescer { delay, action in
            delays.append(delay)
            scheduled = action
            return { scheduled = nil }
        }
        defer { scheduled = nil }
        let manager = TabManager(
            panelTitleUpdateCoalescer: coalescer,
            settings: settings,
            closeTabWarningDefaults: defaults
        )
        defer { manager.tabs.forEach { $0.teardownAllPanels() } }
        let workspace = try #require(manager.selectedWorkspace)
        let focusedPanelId = try #require(workspace.focusedPanelId)
        #expect(workspace.updatePanelTitle(panelId: focusedPanelId, title: "Waiting - grok"))
        #expect(workspace.title == "Waiting - grok")
        let splitPanel = try #require(workspace.newTerminalSplit(
            from: focusedPanelId, orientation: .horizontal, focus: false))
        #expect(workspace.focusedPanelId == focusedPanelId)
        #expect(workspace.panels.count == 2)
        NotificationCenter.default.post(name: .ghosttyDidSetTitle, object: nil, userInfo: [
            GhosttyNotificationKey.tabId: workspace.id,
            GhosttyNotificationKey.surfaceId: focusedPanelId,
            GhosttyNotificationKey.title: "Processing Simple Addition Query - grok"
        ])
        #expect(delays == [PanelTitleUpdateCoalescingSettings.defaultDelay])
        // The real notification must register delivery before this test advances it.
        let delivery = try #require(scheduled)
        #expect(workspace.panelTitles[focusedPanelId] == "Waiting - grok")
        #expect(workspace.title == "Waiting - grok")
        delivery()
        #expect(workspace.panelTitles[focusedPanelId] == "Processing Simple Addition Query - grok")
        #expect(workspace.title == "Processing Simple Addition Query - grok")
        #expect(workspace.customTitle == nil)
        #expect(workspace.panelTitles[splitPanel.id] != Optional(workspace.title))
    }
}
