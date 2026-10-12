import SwiftUI
import BmuxAppKitSupportUI
import AppKit
import BmuxSettings

enum TitlebarNewWorkspaceCloudSplitButtonMetrics {
    static func primaryWidth(config: TitlebarControlsStyleConfig) -> CGFloat { max(MatteTheme(colorScheme: .dark).layout.minimumHitSize, config.buttonSize - 3) }

    static func dropdownWidth(config: TitlebarControlsStyleConfig) -> CGFloat { max(MatteTheme(colorScheme: .dark).layout.minimumHitSize, floor(config.buttonSize * 0.70)) }

    static func dropdownIconSize(config: TitlebarControlsStyleConfig) -> CGFloat { max(6, config.iconSize - 6) }

    static func totalWidth(config: TitlebarControlsStyleConfig) -> CGFloat { primaryWidth(config: config) + dropdownWidth(config: config) }
}

#if DEBUG
enum TitlebarNewWorkspaceCloudSplitButtonForcedHoverSegment: String, CaseIterable, Identifiable {
    case newTab
    case cloudMenu
    case both

    var id: String { rawValue }

    static func stored(rawValue: String) -> Self {
        Self(rawValue: rawValue) ?? .newTab
    }

    fileprivate func includes(_ segment: TitlebarNewWorkspaceCloudSplitButtonSegment) -> Bool {
        switch (self, segment) {
        case (.newTab, .newTab), (.cloudMenu, .cloudMenu), (.both, _):
            return true
        default:
            return false
        }
    }
}

enum TitlebarNewWorkspaceCloudSplitButtonDebugSettings {
    static let alwaysHoverKey = "debugTitlebarSplitButtonAlwaysHover"
    static let forcedHoverSegmentKey = "debugTitlebarSplitButtonForcedHoverSegment"
    static let plusWidthOffsetKey = "debugTitlebarSplitButtonPlusWidthOffset"
    static let caretWidthOffsetKey = "debugTitlebarSplitButtonCaretWidthOffset"
    static let plusPaddingTopKey = "debugTitlebarSplitButtonPlusPaddingTop"
    static let plusPaddingLeadingKey = "debugTitlebarSplitButtonPlusPaddingLeading"
    static let plusPaddingBottomKey = "debugTitlebarSplitButtonPlusPaddingBottom"
    static let plusPaddingTrailingKey = "debugTitlebarSplitButtonPlusPaddingTrailing"
    static let caretPaddingTopKey = "debugTitlebarSplitButtonCaretPaddingTop"
    static let caretPaddingLeadingKey = "debugTitlebarSplitButtonCaretPaddingLeading"
    static let caretPaddingBottomKey = "debugTitlebarSplitButtonCaretPaddingBottom"
    static let caretPaddingTrailingKey = "debugTitlebarSplitButtonCaretPaddingTrailing"

    static let defaultAlwaysHover = false
    static let defaultForcedHoverSegment = TitlebarNewWorkspaceCloudSplitButtonForcedHoverSegment.newTab
    static let defaultPlusWidthOffset = -12.0
    static let defaultCaretWidthOffset = -10.0
    static let defaultPadding = 0.0
    static let defaultPlusPaddingTrailing = -0.7
}
#endif

struct TitlebarNewWorkspaceCloudSplitButton: View {
    let config: TitlebarControlsStyleConfig
    let foregroundColor: Color
    let onNewTab: () -> Void
    @State private var cloudMenuAnchorView: NSView?
    @Environment(\.colorScheme) private var colorScheme
    private var theme: MatteTheme { MatteTheme(colorScheme: colorScheme) }
#if DEBUG
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.alwaysHoverKey)
    private var debugAlwaysHover = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultAlwaysHover
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.forcedHoverSegmentKey)
    private var debugForcedHoverSegmentRaw = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultForcedHoverSegment.rawValue
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.plusWidthOffsetKey)
    private var debugPlusWidthOffset = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPlusWidthOffset
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.caretWidthOffsetKey)
    private var debugCaretWidthOffset = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultCaretWidthOffset
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.plusPaddingTopKey)
    private var debugPlusPaddingTop = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPadding
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.plusPaddingLeadingKey)
    private var debugPlusPaddingLeading = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPadding
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.plusPaddingBottomKey)
    private var debugPlusPaddingBottom = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPadding
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.plusPaddingTrailingKey)
    private var debugPlusPaddingTrailing = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPlusPaddingTrailing
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.caretPaddingTopKey)
    private var debugCaretPaddingTop = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPadding
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.caretPaddingLeadingKey)
    private var debugCaretPaddingLeading = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPadding
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.caretPaddingBottomKey)
    private var debugCaretPaddingBottom = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPadding
    @AppStorage(TitlebarNewWorkspaceCloudSplitButtonDebugSettings.caretPaddingTrailingKey)
    private var debugCaretPaddingTrailing = TitlebarNewWorkspaceCloudSplitButtonDebugSettings.defaultPadding
#endif

    private var dropdownWidth: CGFloat {
        let baseWidth = TitlebarNewWorkspaceCloudSplitButtonMetrics.dropdownWidth(config: config)
#if DEBUG
        return max(
            theme.layout.minimumHitSize,
            baseWidth + CGFloat(debugCaretWidthOffset)
        )
#else
        return baseWidth
#endif
    }

    private var primaryWidth: CGFloat {
        let baseWidth = TitlebarNewWorkspaceCloudSplitButtonMetrics.primaryWidth(config: config)
#if DEBUG
        return max(theme.layout.minimumHitSize, baseWidth + CGFloat(debugPlusWidthOffset))
#else
        return baseWidth
#endif
    }

#if DEBUG
    private var debugForcedHoverSegment: TitlebarNewWorkspaceCloudSplitButtonForcedHoverSegment {
        TitlebarNewWorkspaceCloudSplitButtonForcedHoverSegment.stored(rawValue: debugForcedHoverSegmentRaw)
    }
#endif

    private var plusIconPadding: EdgeInsets {
#if DEBUG
        EdgeInsets(
            top: CGFloat(debugPlusPaddingTop),
            leading: CGFloat(debugPlusPaddingLeading),
            bottom: CGFloat(debugPlusPaddingBottom),
            trailing: CGFloat(debugPlusPaddingTrailing)
        )
#else
        EdgeInsets()
#endif
    }

    private var caretIconPadding: EdgeInsets {
#if DEBUG
        EdgeInsets(
            top: CGFloat(debugCaretPaddingTop),
            leading: CGFloat(debugCaretPaddingLeading),
            bottom: CGFloat(debugCaretPaddingBottom),
            trailing: CGFloat(debugCaretPaddingTrailing)
        )
#else
        EdgeInsets()
#endif
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: config.iconSize, weight: .medium))
                    .padding(plusIconPadding)
                    .frame(width: primaryWidth, height: config.buttonSize)
            }
            .buttonStyle(MatteButtonStyle(config.buttonBackground ? .raised : .flat, theme: theme, forcesHover: segmentForcesHover(.newTab)))
            .frame(width: primaryWidth, height: config.buttonSize)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("titlebarControl.newTab")
            .accessibilityLabel(String(localized: "titlebar.newWorkspace.accessibilityLabel", defaultValue: "New Workspace"))
            .overlay {
                TitlebarSplitButtonRightClickView { anchorView, event in
                    _ = AppDelegate.shared?.showNewWorkspaceContextMenu(anchorView: anchorView, event: event)
                }
            }
            .safeHelp(KeyboardShortcutSettings.Action.newTab.tooltip(String(localized: "titlebar.newWorkspace.tooltip", defaultValue: "New workspace")))

            Button(
                action: {
                    if let cloudMenuAnchorView {
                        _ = AppDelegate.shared?.showNewWorkspaceContextMenu(
                            anchorView: cloudMenuAnchorView,
                            debugSource: "titlebar.newWorkspace.cloudMenu"
                        )
                    } else {
                        _ = AppDelegate.shared?.performCloudVMAction(debugSource: "titlebar.newWorkspace.cloudMenu.fallback")
                    }
                }
            ) {
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                    Image(systemName: "chevron.down")
                        .font(.system(
                            size: TitlebarNewWorkspaceCloudSplitButtonMetrics.dropdownIconSize(config: config),
                            weight: .bold
                        ))
                        .padding(caretIconPadding)
                }
                .frame(width: dropdownWidth, height: config.buttonSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(MatteButtonStyle(config.buttonBackground ? .raised : .flat, theme: theme, forcesHover: segmentForcesHover(.cloudMenu)))
            .frame(width: dropdownWidth, height: config.buttonSize)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("titlebarControl.cloudVM")
            .accessibilityLabel(String(localized: "titlebar.cloudVM.menu.accessibilityLabel", defaultValue: "Cloud VM Menu"))
            .background(TitlebarControlAnchorView { cloudMenuAnchorView = $0 })
            .overlay {
                TitlebarSplitButtonRightClickView { anchorView, event in
                    _ = AppDelegate.shared?.showNewWorkspaceContextMenu(
                        anchorView: anchorView,
                        event: event,
                        debugSource: "titlebar.newWorkspace.cloudMenu.rightClick"
                    )
                }
            }
            .safeHelp(String(localized: "titlebar.cloudVM.menu.tooltip", defaultValue: "Cloud VM actions"))
        }
        .frame(width: primaryWidth + dropdownWidth, height: config.buttonSize)
        .contentShape(Rectangle())
        .background(TitlebarChromeGeometryReporter(keyPrefix: "titlebarControl_newTabCloudSplit"))
        .titlebarInteractiveControl()
    }

    private func segmentForcesHover(_ segment: TitlebarNewWorkspaceCloudSplitButtonSegment) -> Bool {
#if DEBUG
        debugAlwaysHover && debugForcedHoverSegment.includes(segment)
#else
        false
#endif
    }

}

private enum TitlebarNewWorkspaceCloudSplitButtonSegment: Equatable {
    case newTab
    case cloudMenu
}

private struct TitlebarSplitButtonRightClickView: NSViewRepresentable {
    let onRightMouseDown: (NSView, NSEvent) -> Void

    func makeNSView(context: Context) -> TitlebarSplitButtonRightClickNSView {
        let view = TitlebarSplitButtonRightClickNSView()
        view.onRightMouseDown = onRightMouseDown
        return view
    }

    func updateNSView(_ nsView: TitlebarSplitButtonRightClickNSView, context: Context) {
        nsView.onRightMouseDown = onRightMouseDown
    }
}

private final class TitlebarSplitButtonRightClickNSView: NSView {
    var onRightMouseDown: ((NSView, NSEvent) -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point),
              NSApp.currentEvent?.type == .rightMouseDown else {
            return nil
        }
        return self
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightMouseDown?(self, event)
    }
}

struct TitlebarCloudVMButton: View {
    let config: TitlebarControlsStyleConfig
    let foregroundColor: Color

    var body: some View {
        TitlebarControlButton(
            config: config,
            foregroundColor: foregroundColor,
            accessibilityIdentifier: "titlebarControl.cloudVM",
            accessibilityLabel: String(localized: "titlebar.cloudVM.accessibilityLabel", defaultValue: "Cloud VM"),
            action: {
#if DEBUG
                bmuxDebugLog("titlebar.cloudVM")
#endif
                _ = AppDelegate.shared?.performCloudVMAction(debugSource: "titlebar.cloudVM")
            },
            rightClickAction: { anchorView, event in
                Self.showCloudVMMenu(anchorView: anchorView, event: event)
            }
        ) {
            Image(systemName: "cloud")
                .font(.system(size: config.iconSize, weight: .medium))
                .frame(width: config.buttonSize, height: config.buttonSize)
        }
        .safeHelp(String(localized: "titlebar.cloudVM.tooltip", defaultValue: "Open Base"))
    }

    @MainActor
    static func showCloudVMMenu(anchorView: NSView, event: NSEvent) {
        NSMenu.popUpContextMenu(makeCloudVMMenu(), with: event, for: anchorView)
    }

    @MainActor
    static func showCloudVMMenu(anchorView: NSView) {
        let menu = makeCloudVMMenu()
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: anchorView.bounds.maxY + 2),
            in: anchorView
        )
    }

    @MainActor
    static func makeCloudVMMenu() -> NSMenu {
        let menu = NSMenu()
        appendCloudVMMenuItems(to: menu)
        return menu
    }

    @MainActor
    static func appendCloudVMMenuItems(to menu: NSMenu) {
        menu.addItem(mouseDownMenuItem(
            title: String(localized: "command.cloudVM.open.title", defaultValue: "Open Base"),
            action: {
                CloudVMMenuTarget.shared.open()
            }
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(
            title: String(localized: "command.cloudVM.fork.title", defaultValue: "Fork Cloud VM"),
            action: #selector(CloudVMMenuTarget.fork)
        ))
        menu.addItem(menuItem(
            title: String(localized: "command.cloudVM.snapshot.title", defaultValue: "Checkpoint Cloud VM"),
            action: #selector(CloudVMMenuTarget.snapshot)
        ))
        menu.addItem(menuItem(
            title: String(localized: "command.cloudVM.restore.title", defaultValue: "Restore Checkpoint..."),
            action: #selector(CloudVMMenuTarget.restore)
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(advancedMenuItem())
    }

    private static func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = CloudVMMenuTarget.shared
        return item
    }

    private static func mouseDownMenuItem(title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = menuItem(title: title, action: #selector(CloudVMMenuTarget.open))
        item.view = MouseDownMenuItemView(title: title, action: action)
        return item
    }

    private static func advancedMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: "command.cloudVM.advanced.title", defaultValue: "Advanced"),
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()
        submenu.addItem(menuItem(
            title: String(localized: "command.cloudVM.status.title", defaultValue: "Status"),
            action: #selector(CloudVMMenuTarget.status)
        ))
        submenu.addItem(menuItem(
            title: String(localized: "command.cloudVM.ports.title", defaultValue: "Ports"),
            action: #selector(CloudVMMenuTarget.ports)
        ))
        submenu.addItem(NSMenuItem.separator())
        submenu.addItem(menuItem(
            title: String(localized: "command.cloudVM.promoteTemplate.title", defaultValue: "Promote to Template"),
            action: #selector(CloudVMMenuTarget.promoteTemplate)
        ))
        submenu.addItem(menuItem(
            title: String(localized: "command.cloudVM.tools.title", defaultValue: "Inspect Tools"),
            action: #selector(CloudVMMenuTarget.tools)
        ))
        submenu.addItem(menuItem(
            title: String(localized: "command.cloudVM.handoff.title", defaultValue: "Agent Handoff"),
            action: #selector(CloudVMMenuTarget.handoff)
        ))
        item.submenu = submenu
        return item
    }
}

@MainActor
private final class CloudVMMenuTarget: NSObject {
    static let shared = CloudVMMenuTarget()

    @objc func open() {
        _ = AppDelegate.shared?.performCloudVMAction(debugSource: "titlebar.cloudVM.menu.open")
    }

    @objc func fork() {
        _ = AppDelegate.shared?.performCurrentCloudVMCommand(.fork, debugSource: "titlebar.cloudVM.menu.fork")
    }

    @objc func snapshot() {
        _ = AppDelegate.shared?.performCurrentCloudVMCommand(.snapshot, debugSource: "titlebar.cloudVM.menu.snapshot")
    }

    @objc func restore() {
        _ = AppDelegate.shared?.performCloudVMRestoreCommand(debugSource: "titlebar.cloudVM.menu.restore")
    }

    @objc func promoteTemplate() {
        _ = AppDelegate.shared?.performCurrentCloudVMCommand(.promoteTemplate, debugSource: "titlebar.cloudVM.menu.promoteTemplate")
    }

    @objc func status() {
        _ = AppDelegate.shared?.performCurrentCloudVMCommand(.status, debugSource: "titlebar.cloudVM.menu.status")
    }

    @objc func ports() {
        _ = AppDelegate.shared?.performCurrentCloudVMCommand(.ports, debugSource: "titlebar.cloudVM.menu.ports")
    }

    @objc func tools() {
        _ = AppDelegate.shared?.performCurrentCloudVMCommand(.tools, debugSource: "titlebar.cloudVM.menu.tools")
    }

    @objc func handoff() {
        _ = AppDelegate.shared?.performCurrentCloudVMCommand(.handoff, debugSource: "titlebar.cloudVM.menu.handoff")
    }
}
