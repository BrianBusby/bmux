import BmuxAppKitSupportUI
import SwiftUI

/// Renders one immutable workspace snapshot with independent native actions.
struct WorkspaceReferenceCardView: View {
    let card: WorkspaceReferenceCardSnapshot
    let repositoryName: String?
    let isSelected: Bool
    let canCloseWorkspace: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onOpenLink: (URL) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var focusedControl: Control?

    private enum Control: Hashable { case selection, close, ticket, project, pullRequest, owner }
    private var theme: MatteTheme { MatteTheme(colorScheme: colorScheme) }
    private var showsClose: Bool { isSelected || (isEnabled && (isHovered || focusedControl != nil)) }

    var body: some View {
        let motion = theme.motion(reduceMotion: reduceMotion)
        content
            .opacity(isEnabled ? 1 : theme.layout.disabledOpacity)
            .padding(theme.layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                MatteButton(action: onSelect, onFocusChange: { updateFocus(.selection, isFocused: $0) }) {
                    Color.clear.contentShape(RoundedRectangle(cornerRadius: theme.layout.cardRadius))
                }
                .buttonStyle(WorkspaceReferenceCardButtonStyle(
                    theme: theme, isSelected: isSelected, isHovered: isHovered,
                    isFocused: focusedControl == .selection, isEnabled: isEnabled, isPressed: $isPressed))
                .accessibilityLabel(card.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("WorkspaceReferenceCard.select.\(card.id)")
            }
            .offset(y: -theme.cardLift(isHovered: isHovered, isSelected: isSelected,
                                      isPressed: isPressed, isEnabled: isEnabled, reduceMotion: reduceMotion))
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .timingCurve(motion.curve.x1, motion.curve.y1,
                motion.curve.x2, motion.curve.y2, duration: motion.cardDuration), value: isHovered)
            .animation(reduceMotion ? nil : .timingCurve(motion.curve.x1, motion.curve.y1,
                motion.curve.x2, motion.curve.y2, duration: motion.cardDuration), value: isPressed)
            .animation(reduceMotion ? nil : .timingCurve(motion.curve.x1, motion.curve.y1,
                motion.curve.x2, motion.curve.y2, duration: motion.cardDuration), value: isSelected)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: theme.layout.cardContentGap) {
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    if repositoryName != nil || isSelected {
                        HStack(spacing: 4) {
                            if isSelected {
                                Rectangle()
                                    .frame(width: theme.layout.selectedMarkerSize, height: theme.layout.selectedMarkerSize)
                                    .foregroundStyle(color(.selectionRing))
                                    .accessibilityHidden(true)
                            }
                            if let repositoryName {
                                Text(repositoryName)
                                    .matteTypography(.repositoryLabel, theme: theme)
                                    .foregroundStyle(color(.sage))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    if let ticketID = card.ticketID {
                        linkRow(icon: "ticket", text: ticketID, url: card.ticketURL, control: .ticket)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if card.hasActiveAIWork {
                    let label = String(localized: "sidebar.aiBusy.tooltip", defaultValue: "AI is running or needs input")
                    TronLoadingIndicator(size: 18, color: color(.textSecondary), lineWidth: 1.5)
                        .frame(width: theme.layout.minimumHitSize, height: theme.layout.minimumHitSize)
                        .safeHelp(label)
                        .accessibilityLabel(label)
                        .allowsHitTesting(false)
                }
                MatteButton(hitExpansion: theme.layout.invisibleHitExpansion, action: onClose, onFocusChange: { updateFocus(.close, isFocused: $0) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.layout.smallIconSize, weight: .medium))
                        .frame(width: theme.layout.minimumHitSize, height: theme.layout.minimumHitSize)
                }
                .buttonStyle(MatteButtonStyle(.flat, theme: theme, dimsWhenDisabled: isEnabled))
                .frame(height: theme.layout.smallIconSize)
                .disabled(!canCloseWorkspace || card.hasActiveAIWork)
                .opacity(showsClose ? 1 : 0)
                .allowsHitTesting(showsClose)
                .accessibilityLabel(String(localized: "sidebar.closeWorkspace.tooltip", defaultValue: "Close Workspace"))
                .safeHelp(String(localized: "sidebar.closeWorkspace.tooltip", defaultValue: "Close Workspace"))
                .accessibilityIdentifier("WorkspaceReferenceCard.close.\(card.id)")
            }
            Text(card.title)
                .matteTypography(.cardTitle, theme: theme)
                .foregroundStyle(color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            if let projectTitle = card.projectTitle {
                linkRow(icon: "folder", text: projectTitle, url: card.projectURL, control: .project)
            }
            if let pullRequestText = card.pullRequestText {
                linkRow(icon: "arrow.triangle.pull", text: pullRequestText, url: card.pullRequestURL, control: .pullRequest)
            }
            if let ownerName = card.ownerName {
                ownerRow(ownerName)
            }
            if card.prompt != nil || card.branch != nil || card.isDirty != nil {
                Rectangle().fill(color(.edge)).frame(height: 1).allowsHitTesting(false)
                if let prompt = card.prompt {
                    Text(prompt)
                        .matteTypography(.previewLine, theme: theme)
                        .foregroundStyle(color(.textSecondary))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                }
                if let branchStatus {
                    Text(branchStatus)
                        .font(.system(size: theme.typography(.body).pointSize, design: .monospaced))
                        .foregroundStyle(color(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var branchStatus: String? {
        let status = card.isDirty.map {
            String(localized: $0 ? "sidebar.workspace.card.uncommittedChanges" : "sidebar.workspace.card.clean",
                   defaultValue: $0 ? "uncommitted changes" : "clean")
        }
        let pieces = [card.branch, status].compactMap { $0 }
        return pieces.isEmpty ? nil : pieces.joined(separator: " · ")
    }

    @ViewBuilder
    private func linkRow(icon: String, text: String, url: URL?, control: Control) -> some View {
        let label = HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: theme.layout.smallIconSize, weight: .medium))
                .frame(width: theme.layout.smallIconSize)
            Text(text).underline(url != nil).lineLimit(2).truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .matteTypography(.body, theme: theme)
        .frame(minHeight: theme.layout.minimumHitSize, alignment: .leading)
        if let url {
            MatteButton(hitExpansion: theme.layout.invisibleHitExpansion, action: { onOpenLink(url) }, onFocusChange: { updateFocus(control, isFocused: $0) }) { label }
                .buttonStyle(MatteButtonStyle(.link, theme: theme, dimsWhenDisabled: isEnabled))
        } else {
            label.foregroundStyle(color(.textSecondary)).allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func ownerRow(_ name: String) -> some View {
        let label = HStack(spacing: 8) {
            Text(card.ownerInitials ?? "")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color(.textSecondary))
                .frame(width: 24, height: 24)
                .background(color(.chip), in: Circle())
            Text(name).matteTypography(.body, theme: theme).lineLimit(1)
        }
        .frame(minHeight: theme.layout.minimumHitSize)
        if let url = card.ownerURL {
            MatteButton(hitExpansion: theme.layout.invisibleHitExpansion, action: { onOpenLink(url) }, onFocusChange: { updateFocus(.owner, isFocused: $0) }) { label }
                .buttonStyle(MatteButtonStyle(.link, theme: theme, dimsWhenDisabled: isEnabled))
        } else {
            label.foregroundStyle(color(.textSecondary)).allowsHitTesting(false)
        }
    }

    private func updateFocus(_ control: Control, isFocused: Bool) {
        if isFocused {
            focusedControl = control
        } else if focusedControl == control {
            focusedControl = nil
        }
    }

    private func color(_ role: MatteColorRole) -> Color { Color(nsColor: theme.color(role)) }
}
