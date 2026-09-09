import Foundation

@MainActor
struct MenuBarPresentationRuntimeUIActions {
    var makeMenuBarExtraController: () -> any MenuBarPresentationMenuBarExtraControlling
}
