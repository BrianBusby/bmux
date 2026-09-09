import Foundation

@MainActor
protocol MenuBarPresentationMenuBarExtraControlling: AnyObject {
    func removeFromMenuBar()
    func refreshForDebugControls()

    @discardableResult
    func toggleGlobalSearchPalette(onDismiss: (() -> Void)?) -> Bool
}

extension MenuBarExtraController: MenuBarPresentationMenuBarExtraControlling {}
