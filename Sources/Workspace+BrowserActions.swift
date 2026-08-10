import Foundation

extension Workspace {
    /// Open a browser next to a source panel, reusing the nearest right-side pane
    /// when the layout already provides one.
    @discardableResult
    func openBrowserSplitForAction(
        from sourcePanelId: UUID,
        url: URL? = nil,
        focus: Bool = true,
        selectWhenNotFocused: Bool = true,
        creationPolicy: BrowserPanelCreationPolicy = .userInitiated,
        omnibarVisible: Bool = true,
        transparentBackground: Bool = false,
        bypassRemoteProxy: Bool = false
    ) -> (panel: BrowserPanel, createdSplit: Bool, placementStrategy: String)? {
        guard panels[sourcePanelId] != nil else { return nil }

        if let targetPane = preferredRightSideTargetPane(fromPanelId: sourcePanelId),
           let panel = newBrowserSurface(
               inPane: targetPane,
               url: url,
               focus: focus,
               selectWhenNotFocused: selectWhenNotFocused,
               creationPolicy: creationPolicy,
               omnibarVisible: omnibarVisible,
               transparentBackground: transparentBackground,
               bypassRemoteProxy: bypassRemoteProxy
           ) {
            return (panel, false, "reuse_right_sibling")
        }

        guard let panel = newBrowserSplit(
            from: sourcePanelId,
            orientation: .horizontal,
            url: url,
            focus: focus,
            creationPolicy: creationPolicy,
            omnibarVisible: omnibarVisible,
            transparentBackground: transparentBackground,
            bypassRemoteProxy: bypassRemoteProxy
        ) else {
            return nil
        }
        return (panel, true, "split_right")
    }
}
