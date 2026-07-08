import XCTest
import BmuxSettings
@testable import BmuxSettingsUI

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

private typealias ShortcutStroke = BmuxSettings.ShortcutStroke

final class KeyboardShortcutSavedLayoutTemplateTests: XCTestCase {
    func testSaveLayoutTemplateSettingsPackageActionStaysAligned() {
        guard let settingsAction = ShortcutAction(
            rawValue: KeyboardShortcutSettings.Action.saveLayoutTemplate.rawValue
        ) else {
            XCTFail("Expected BmuxSettings.ShortcutAction for saveLayoutTemplate")
            return
        }
        XCTAssertEqual(settingsAction.defaultStroke, ShortcutStroke(key: "s", command: true, control: true))
        XCTAssertEqual(settingsAction.displayName, KeyboardShortcutSettings.Action.saveLayoutTemplate.label)
    }
}
