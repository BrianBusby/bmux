import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct TitlebarProductContractTests {
    @Test func defaultSidebarTracksItsWidthWhenVisibleAndMinimumWhenHidden() {
        let width = CGFloat(SessionPersistencePolicy.defaultSidebarWidth)
        let minimum = CGFloat(SessionPersistencePolicy.minimumSidebarWidth)
        // The workspace-card layout intentionally starts wider than its resize minimum.
        #expect(width == 340)
        #expect(minimum == 240)
        let visible = ContentView.customTitlebarLeadingPadding(
            isFullScreen: false, isSidebarVisible: true, sidebarWidth: width,
            minimumSidebarWidth: minimum, titlebarLeadingInset: 82
        )
        let hidden = ContentView.customTitlebarLeadingPadding(
            isFullScreen: false, isSidebarVisible: false, sidebarWidth: width,
            minimumSidebarWidth: minimum, titlebarLeadingInset: 82
        )
        #expect(visible == 352)
        #expect(hidden == 252)
    }

    @Test func titlebarHintsIncludeVoiceInputAndFocusHistoryInControlOrder() {
        #expect(TitlebarShortcutHintActionSlot.allCases.map(\.action) == [
            .toggleSidebar,
            .showNotifications,
            .pushToTalkVoiceInput,
            .newTab,
            .focusHistoryBack,
            .focusHistoryForward,
        ])
    }
}
