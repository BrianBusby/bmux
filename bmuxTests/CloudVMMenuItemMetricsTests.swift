import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite(.serialized)
struct CloudVMMenuItemMetricsTests {
    @Test func mouseDownCloudVMMenuRowMatchesNativeMenuItemHeight() throws {
        let menu = TitlebarCloudVMButton.makeCloudVMMenu()
        let firstView = try #require(menu.items.first?.view)
        let nativeRowHeight = MouseDownMenuItemView.nativeMenuItemRowHeight()

        #expect(abs(firstView.frame.height - nativeRowHeight) < 0.5)
        #expect(abs(nativeRowHeight - Self.expectedNativeMenuItemRowHeight()) < 0.5)
    }

    private static func expectedNativeMenuItemRowHeight() -> Double {
        let oneItemMenu = NSMenu()
        oneItemMenu.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))

        let twoItemMenu = NSMenu()
        twoItemMenu.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))
        twoItemMenu.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))

        return twoItemMenu.size.height - oneItemMenu.size.height
    }
}
