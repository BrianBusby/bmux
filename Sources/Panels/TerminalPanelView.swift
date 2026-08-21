import SwiftUI
import Foundation
import AppKit
import Bonsplit
import BmuxAppKitSupportUI
import BmuxTestSupport
import BmuxTerminal
import BmuxFoundation

/// View for rendering a terminal panel
struct TerminalPanelView: View {
    @ObservedObject var panel: TerminalPanel
    @AppStorage(NotificationPaneRingSettings.enabledKey)
    private var notificationPaneRingEnabled = NotificationPaneRingSettings.defaultEnabled
    @AppStorage(TerminalTextBoxInputSettings.maxLinesKey)
    private var textBoxMaxLines = TerminalTextBoxInputSettings.defaultMaxLines
    @State private var terminalFontSize = GhosttyConfig.load(globalFontMagnificationPercent: GlobalFontMagnification.storedPercent).fontSize
    let paneId: PaneID
    let isFocused: Bool
    let isVisibleInUI: Bool
    let portalPriority: Int
    let isSplit: Bool
    let appearance: PanelAppearance
    let hasUnreadNotification: Bool
    let terminalAgentContext: String
    var stableWorkspaceId: UUID? = nil
    var workProvenanceRuntime: WorkProvenanceRuntime? = nil
    let onFocus: () -> Void
    let onResumeAgentHibernation: () -> Void
    let onAutoResumeAgentHibernation: () -> Void
    let onTriggerFlash: () -> Void

    var body: some View {
        if let hibernationState = panel.agentHibernationState {
            hibernationBody(hibernationState)
        } else {
            terminalBody
        }
    }

    @ViewBuilder
    private func hibernationBody(_ hibernationState: AgentHibernationPanelState) -> some View {
        if isVisibleInUI {
            Color(nsColor: appearance.contentBackgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("hibernated-resuming-\(panel.id.uuidString)")
                .onAppear {
                    onAutoResumeAgentHibernation()
                }
        } else {
            AgentHibernationPlaceholderView(
                state: hibernationState,
                appearance: appearance,
                onResume: onResumeAgentHibernation
            )
            .id("hibernated-\(panel.id.uuidString)")
            .onChange(of: isVisibleInUI) { _, visible in
                if visible {
                    onAutoResumeAgentHibernation()
                }
            }
        }
    }

    private var terminalBody: some View {
        AgentSessionFactualProjectionModeHost(
            showsSwitcher: showsFactualSessionSwitcher,
            stableWorkspaceID: stableWorkspaceId,
            workProvenanceRuntime: workProvenanceRuntime,
            backgroundColor: appearance.contentBackgroundColor
        ) { isVisibleForMode in
            terminalSurfaceBody(isVisibleForMode: isVisibleForMode)
        }
    }

    private func terminalSurfaceBody(isVisibleForMode: Bool) -> some View {
        @Bindable var textBoxState = panel.textBoxState
        let terminalIsVisibleInUI = isVisibleInUI && isVisibleForMode

        return VStack(spacing: 0) {
            // Layering contract: terminal find UI is mounted in GhosttySurfaceScrollView (AppKit portal layer)
            // via `searchState`. Rendering `SurfaceSearchOverlay` in this SwiftUI container can hide it.
            GhosttyTerminalView(
                terminalSurface: panel.surface,
                paneId: paneId,
                isActive: isFocused && isVisibleForMode,
                isVisibleInUI: terminalIsVisibleInUI,
                portalZPriority: portalPriority,
                showsInactiveOverlay: terminalIsVisibleInUI && isSplit && !isFocused,
                showsUnreadNotificationRing: terminalIsVisibleInUI && hasUnreadNotification && notificationPaneRingEnabled,
                inactiveOverlayColor: appearance.unfocusedOverlayNSColor,
                inactiveOverlayOpacity: appearance.unfocusedOverlayOpacity,
                searchState: panel.searchState,
                promptNavigationHasBookmarks: panel.promptNavigationHasBookmarks,
                promptNavigationCanMoveBackward: panel.promptNavigationCanMoveBackward,
                promptNavigationCanMoveForward: panel.promptNavigationCanMoveForward,
                reattachToken: panel.viewReattachToken,
                onFocus: { _ in
                    panel.terminalDidBecomeFocused()
                    onFocus()
                },
                onTriggerFlash: onTriggerFlash,
                onNavigatePrompt: { delta in
                    _ = panel.navigatePromptBookmark(delta: delta)
                }
            )
            // Keep the NSViewRepresentable identity stable across bonsplit structural updates.
            // This prevents transient teardown/recreate that can momentarily detach the hosted terminal view.
            .id(panel.id)
            .background(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
#if DEBUG
            .reportTerminalViewportGeometryForUITest(panel: panel)
#endif
            .layoutPriority(1)

            if panel.isTextBoxActive {
                TextBoxInputContainer(
                    text: $panel.textBoxContent,
                    attachments: $panel.textBoxAttachments,
                    selectedSubmitActionID: $textBoxState.selectedSubmitActionID,
                    pendingProviderLaunchAction: $textBoxState.pendingProviderLaunchAction,
                    pendingProviderLaunchStartedAt: $textBoxState.pendingProviderLaunchStartedAt,
                    surface: panel.surface,
                    terminalBackgroundColor: appearance.backgroundColor,
                    terminalForegroundColor: appearance.foregroundColor,
                    terminalFont: NSFont.monospacedSystemFont(
                        ofSize: terminalFontSize,
                        weight: .regular
                    ),
                    maxLines: TerminalTextBoxInputSettings.resolvedMaxLines(textBoxMaxLines),
                    terminalAgentContext: effectiveTerminalAgentContext,
                    shellActivityState: panel.shellActivity.state,
                    allowsCommandTemplateSubmit: TextBoxInputContainer.allowsCommandTemplateSubmit(
                        shellActivityState: panel.shellActivity.state
                    ),
                    onFocusTextBox: {
                        panel.textBoxDidBecomeFocused()
                        onFocus()
                    },
                    onToggleFocus: {
                        _ = panel.focusTextBoxInputOrTerminal()
                    },
                    onRecordLaunchCommand: { command in
                        panel.recordTextBoxLaunchCommand(command)
                    },
                    onClearLaunchCommand: {
                        panel.clearTextBoxLaunchCommand()
                    },
                    onEscape: {
                        panel.handleTextBoxEscape()
                    },
                    onTextViewCreated: { view in
                        panel.registerTextBoxInputView(view)
                    },
                    onTextViewMovedToWindow: { view in
                        panel.textBoxInputViewDidMoveToWindow(view)
                    },
                    onTextViewDismantled: { view in
                        panel.preserveTextBoxContentForUnmount(from: view)
                    }
                )
                .overlay {
                    TextBoxPromptNavigationPulseView(
                        pulseSeed: panel.promptNavigationTextBoxPulseSeed
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .ghosttyConfigDidReload)) { _ in
            terminalFontSize = GhosttyConfig.load(globalFontMagnificationPercent: GlobalFontMagnification.storedPercent).fontSize
        }
    }

    private var showsFactualSessionSwitcher: Bool {
        Self.shouldShowFactualSessionSwitcher(
            terminalAgentContext: effectiveTerminalAgentContext,
            panelTitle: panel.displayTitle,
            hasStableWorkspace: stableWorkspaceId != nil,
            workProvenanceRuntimeAvailable: workProvenanceRuntime != nil
        )
    }

    private static func shouldShowFactualSessionSwitcher(
        terminalAgentContext: String,
        panelTitle: String,
        hasStableWorkspace: Bool,
        workProvenanceRuntimeAvailable: Bool
    ) -> Bool {
        guard hasStableWorkspace,
              workProvenanceRuntimeAvailable else {
            return false
        }
        if TextBoxAgentDetection.codex.matches(context: terminalAgentContext) {
            return true
        }
        let normalizedTitle = panelTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedTitle == "codex"
    }

    private var effectiveTerminalAgentContext: String {
        Self.effectiveTerminalAgentContext(
            terminalAgentContext,
            pendingLaunchCommand: panel.textBoxState.pendingLaunchCommand
        )
    }

    static func effectiveTerminalAgentContext(
        _ terminalAgentContext: String,
        pendingLaunchCommand: String?
    ) -> String {
        var context = terminalAgentContext
        appendTextBoxLaunchContext(
            "textBoxPendingLaunchCommand:",
            command: pendingLaunchCommand,
            to: &context
        )
        return context
    }

    private static func appendTextBoxLaunchContext(
        _ prefix: String,
        command: String?,
        to context: inout String
    ) {
        guard let command = command?.trimmingCharacters(in: .whitespacesAndNewlines),
              !command.isEmpty else { return }
        let marker = "\(prefix)\(command)"
        let existingLines = context
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard !existingLines.contains(marker) else { return }
        if context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context = marker
        } else {
            context += "\n\(marker)"
        }
    }
}

private struct TextBoxPromptNavigationPulseView: NSViewRepresentable {
    let pulseSeed: UInt64

    func makeNSView(context: Context) -> TextBoxPromptNavigationPulseNSView {
        TextBoxPromptNavigationPulseNSView(frame: .zero)
    }

    func updateNSView(_ nsView: TextBoxPromptNavigationPulseNSView, context: Context) {
        nsView.pulse(seed: pulseSeed)
    }
}

private final class TextBoxPromptNavigationPulseNSView: NSView {
    private let pulseLayer = CAShapeLayer()
    private var lastPulseSeed: UInt64 = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        let pulseColor = bmuxAccentNSColor()
        pulseLayer.fillColor = pulseColor.withAlphaComponent(0.2).cgColor
        pulseLayer.strokeColor = pulseColor.withAlphaComponent(0.55).cgColor
        pulseLayer.lineWidth = 1
        pulseLayer.shadowColor = pulseColor.cgColor
        pulseLayer.shadowOpacity = 0.26
        pulseLayer.shadowRadius = 12
        pulseLayer.shadowOffset = .zero
        pulseLayer.opacity = 0
        layer?.addSublayer(pulseLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        updatePath()
    }

    func pulse(seed: UInt64) {
        guard seed != 0,
              seed != lastPulseSeed else { return }
        lastPulseSeed = seed
        updatePath()
        pulseLayer.removeAllAnimations()
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = FocusFlashPattern.values.map { NSNumber(value: $0 * 0.5) }
        animation.keyTimes = FocusFlashPattern.keyTimes.map { NSNumber(value: $0) }
        animation.duration = FocusFlashPattern.duration
        animation.timingFunctions = FocusFlashPattern.curves.map { curve in
            switch curve {
            case .easeIn:
                return CAMediaTimingFunction(name: .easeIn)
            case .easeOut:
                return CAMediaTimingFunction(name: .easeOut)
            }
        }
        pulseLayer.add(animation, forKey: "bmux.textBoxPromptNavigationPulse")
    }

    private func updatePath() {
        let rect = bounds.insetBy(dx: 8, dy: 4)
        guard rect.width > 0,
              rect.height > 0 else { return }
        pulseLayer.path = CGPath(
            roundedRect: rect,
            cornerWidth: min(14, rect.height / 2),
            cornerHeight: min(14, rect.height / 2),
            transform: nil
        )
    }
}

private struct AgentHibernationPlaceholderView: View {
    let state: AgentHibernationPanelState
    let appearance: PanelAppearance
    let onResume: () -> Void

    private var lastActivityText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: state.lastActivityAt, relativeTo: Date())
    }

    var body: some View {
        VStack(spacing: 14) {
            BmuxSystemSymbolImage(magnified: "pause.circle", pointSize: 34, weight: .regular)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text(String(localized: "terminal.agentHibernation.title", defaultValue: "Agent hibernated"))
                    .bmuxFont(.headline)
                Text(state.agentDisplayName)
                    .bmuxFont(.subheadline)
                    .foregroundStyle(.secondary)
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "terminal.agentHibernation.lastActivity", defaultValue: "Last activity %@"),
                        lastActivityText
                    )
                )
                .bmuxFont(.caption)
                .foregroundStyle(.tertiary)
            }
            Button(String(localized: "terminal.agentHibernation.resume", defaultValue: "Resume")) {
                onResume()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("AgentHibernationResumeButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: appearance.contentBackgroundColor))
    }
}

#if DEBUG
private extension View {
    func reportTerminalViewportGeometryForUITest(panel: TerminalPanel) -> some View {
        modifier(TerminalViewportGeometryReporter(panel: panel))
    }
}

private struct TerminalViewportGeometryReporter: ViewModifier {
    @ObservedObject var panel: TerminalPanel

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        recordTerminalViewportGeometryForUITest(proxy: proxy, panel: panel)
                    }
                    .onChange(of: proxy.size) {
                        recordTerminalViewportGeometryForUITest(proxy: proxy, panel: panel)
                    }
            }
        }
    }
}

@MainActor
private func recordTerminalViewportGeometryForUITest(proxy: GeometryProxy, panel: TerminalPanel) {
    let env = ProcessInfo.processInfo.environment
    guard env["BMUX_UI_TEST_TERMINAL_VIEWPORT_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        return
    }

    let hostedView = panel.hostedView
    let hostedFrame = hostedView.frame
    let hostedBounds = hostedView.bounds
    let hostedSuperviewBounds = hostedView.superview?.bounds ?? .zero
    let windowContentBounds = hostedView.window?.contentView?.bounds ?? .zero
    let hostedFrameInContent: NSRect
    if let contentView = hostedView.window?.contentView {
        hostedFrameInContent = contentView.convert(hostedView.convert(hostedView.bounds, to: nil), from: nil)
    } else {
        hostedFrameInContent = .zero
    }

    _ = UITestCaptureSink().mutateJSONObjectIfConfigured(envKey: "BMUX_UI_TEST_TERMINAL_VIEWPORT_PATH") { payload in
        payload["terminalViewportPanelId"] = panel.id.uuidString
        payload["terminalViewportPanelWidth"] = terminalViewportFormat(proxy.size.width)
        payload["terminalViewportPanelHeight"] = terminalViewportFormat(proxy.size.height)
        payload["terminalViewportHostedFrameMinX"] = terminalViewportFormat(hostedFrame.minX)
        payload["terminalViewportHostedFrameMinY"] = terminalViewportFormat(hostedFrame.minY)
        payload["terminalViewportHostedFrameMaxX"] = terminalViewportFormat(hostedFrame.maxX)
        payload["terminalViewportHostedFrameMaxY"] = terminalViewportFormat(hostedFrame.maxY)
        payload["terminalViewportHostedFrameWidth"] = terminalViewportFormat(hostedFrame.width)
        payload["terminalViewportHostedFrameHeight"] = terminalViewportFormat(hostedFrame.height)
        payload["terminalViewportHostedBoundsWidth"] = terminalViewportFormat(hostedBounds.width)
        payload["terminalViewportHostedBoundsHeight"] = terminalViewportFormat(hostedBounds.height)
        payload["terminalViewportHostedSuperviewWidth"] = terminalViewportFormat(hostedSuperviewBounds.width)
        payload["terminalViewportHostedSuperviewHeight"] = terminalViewportFormat(hostedSuperviewBounds.height)
        payload["terminalViewportWindowContentWidth"] = terminalViewportFormat(windowContentBounds.width)
        payload["terminalViewportWindowContentHeight"] = terminalViewportFormat(windowContentBounds.height)
        payload["terminalViewportHostedContentMinX"] = terminalViewportFormat(hostedFrameInContent.minX)
        payload["terminalViewportHostedContentMinY"] = terminalViewportFormat(hostedFrameInContent.minY)
        payload["terminalViewportHostedContentMaxX"] = terminalViewportFormat(hostedFrameInContent.maxX)
        payload["terminalViewportHostedContentMaxY"] = terminalViewportFormat(hostedFrameInContent.maxY)
    }
}

private func terminalViewportFormat(_ value: CGFloat) -> String {
    String(format: "%.3f", Double(value))
}
#endif

/// Shared appearance settings for panels
struct PanelAppearance {
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let dividerColor: Color
    let unfocusedOverlayNSColor: NSColor
    let unfocusedOverlayOpacity: Double
    let usesClearContentBackground: Bool

    var contentBackgroundColor: NSColor {
        usesClearContentBackground ? .clear : backgroundColor
    }

    var drawsContentBackground: Bool {
        !usesClearContentBackground
    }

    static func fromConfig(_ config: GhosttyConfig) -> PanelAppearance {
        fromConfig(
            config,
            usesTransparentWindow: WindowBackgroundComposition.policy
                .shouldUseTransparentBackgroundWindow(glassEffectAvailable: false)
        )
    }

    static func fromConfig(_ config: GhosttyConfig, usesTransparentWindow: Bool) -> PanelAppearance {
        let backgroundColor = GhosttyBackgroundTheme.color(
            backgroundColor: config.backgroundColor,
            opacity: config.backgroundOpacity
        )
        return PanelAppearance(
            backgroundColor: backgroundColor,
            foregroundColor: bmuxReadableForegroundNSColor(
                preferred: config.foregroundColor,
                on: backgroundColor
            ),
            dividerColor: Color(nsColor: config.resolvedSplitDividerColor),
            unfocusedOverlayNSColor: config.unfocusedSplitOverlayFill,
            unfocusedOverlayOpacity: config.unfocusedSplitOverlayOpacity,
            usesClearContentBackground: shouldUseClearContentBackground(
                opacity: config.backgroundOpacity,
                usesGhosttyGlassStyle: config.backgroundBlur.isMacOSGlassStyle,
                usesTransparentWindow: usesTransparentWindow
            )
        )
    }

    static func shouldUseClearContentBackground(
        opacity: Double,
        usesGhosttyGlassStyle: Bool,
        usesTransparentWindow: Bool
    ) -> Bool {
        usesTransparentWindow || usesGhosttyGlassStyle || opacity < 0.999
    }
}
