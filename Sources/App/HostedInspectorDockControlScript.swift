struct HostedInspectorDockControlScript {
    let allowSideDock: Bool
    let detachedFromHostWindow: Bool

    var source: String {
        let allowSideDockLiteral = allowSideDock ? "true" : "false"
        let detachedFromHostWindowLiteral = detachedFromHostWindow ? "true" : "false"
        return """
        (() => {
            if (typeof WI === "undefined")
                return null;
            const allowSideDock = \(allowSideDockLiteral);
            const detachedFromHostWindow = \(detachedFromHostWindowLiteral);
            function callOriginal(fn, event) {
                return typeof fn === "function" ? fn.call(WI, event) : null;
            }
            function installWrapper(methodName, originalName, wrapper) {
                if (typeof WI[originalName] !== "function") {
                    if (typeof WI[methodName] !== "function")
                        return false;
                    WI[originalName] = WI[methodName];
                }
                WI[methodName] = wrapper;
                return true;
            }
            function updateButton(button, hidden) {
                if (!button)
                    return;
                button.hidden = hidden;
                if (button.element) {
                    button.element.style.display = hidden ? "none" : "";
                    button.element.style.pointerEvents = hidden ? "none" : "";
                }
            }
            function updateButtons(buttons, hidden) {
                for (const button of buttons)
                    updateButton(button, hidden);
            }
            function dockMatches(enumValue, literal) {
                const configuration = WI.dockConfiguration;
                if (configuration === enumValue)
                    return true;
                return String(configuration).toLowerCase() === literal;
            }
            function enforceDockControls() {
                const disallowSideDock = !WI.__bmuxAllowSideDock;
                const dockConfiguration = WI.DockConfiguration || {};
                const dockedLeft = dockMatches(dockConfiguration.Left, "left");
                const dockedRight = dockMatches(dockConfiguration.Right, "right");
                const dockedBottom = !WI.__bmuxDetachedFromHostWindow &&
                    dockMatches(dockConfiguration.Bottom, "bottom");
                const detached = WI.__bmuxDetachedFromHostWindow ||
                    dockMatches(dockConfiguration.Detached, "detached") ||
                    dockMatches(dockConfiguration.Undocked, "undocked");
                updateButton(WI._dockLeftTabBarButton, disallowSideDock || (!detached && dockedLeft));
                updateButton(WI._dockRightTabBarButton, disallowSideDock || (!detached && dockedRight));
                updateButtons([
                    WI._dockBottomTabBarButton,
                    WI._dockBottomNavigationItem,
                    WI._dockBottomButton,
                ], !detached && dockedBottom);
                updateButtons([
                    WI._detachTabBarButton,
                    WI._detachNavigationItem,
                    WI._undockTabBarButton,
                    WI._undockButton,
                ], detached);
            }
            WI.__bmuxAllowSideDock = allowSideDock;
            WI.__bmuxDetachedFromHostWindow = detachedFromHostWindow;
            installWrapper("_dockLeft", "__bmuxOriginalDockLeft", function(event) {
                if (!WI.__bmuxAllowSideDock)
                    return callOriginal(WI._dockBottom, event);
                return callOriginal(WI.__bmuxOriginalDockLeft, event);
            });
            installWrapper("_dockRight", "__bmuxOriginalDockRight", function(event) {
                if (!WI.__bmuxAllowSideDock)
                    return callOriginal(WI._dockBottom, event);
                return callOriginal(WI.__bmuxOriginalDockRight, event);
            });
            installWrapper("_togglePreviousDockConfiguration", "__bmuxOriginalTogglePreviousDockConfiguration", function(event) {
                const dockConfiguration = WI.DockConfiguration || {};
                const previousSideDock = WI._previousDockConfiguration === dockConfiguration.Left ||
                    WI._previousDockConfiguration === dockConfiguration.Right;
                if (!WI.__bmuxAllowSideDock && previousSideDock)
                    return callOriginal(WI._dockBottom, event);
                return callOriginal(WI.__bmuxOriginalTogglePreviousDockConfiguration, event);
            });
            installWrapper("_updateDockNavigationItems", "__bmuxOriginalUpdateDockNavigationItems", function(...args) {
                if (typeof WI.__bmuxOriginalUpdateDockNavigationItems === "function")
                    WI.__bmuxOriginalUpdateDockNavigationItems.apply(WI, args);
                enforceDockControls();
            });
            if (typeof WI._updateDockNavigationItems === "function")
                WI._updateDockNavigationItems();
            else
                enforceDockControls();
            return WI.__bmuxAllowSideDock;
        })();
        """
    }
}
