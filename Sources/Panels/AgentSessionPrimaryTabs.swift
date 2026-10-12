import AppKit
import SwiftUI
import BmuxAppKitSupportUI

/// Presents the existing primary navigation from immutable selection and actions.
struct AgentSessionPrimaryTabs: View {
    let selected: AgentSessionFactualProjectionMode
    let onSelect: (AgentSessionFactualProjectionMode) -> Void
    let onHostChange: (@MainActor (NSView, Bool) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MatteTheme(colorScheme: colorScheme)
        WorkspaceChromeFocusScope(usesIntrinsicSize: true, expandsToProposedWidth: true, onAttachmentChange: { host, attached in
            onHostChange?(host, attached)
        }) {
            HStack(spacing: theme.layout.primaryNavigationGap) {
                ForEach(AgentSessionFactualProjectionMode.allCases) { mode in
                    MatteButton { onSelect(mode) } label: {
                        Text(mode.title)
                            .matteTypography(.tab, theme: theme)
                            .foregroundStyle(Color(nsColor: theme.color(selected == mode ? .textPrimary : .textSecondary)))
                            .frame(minHeight: theme.layout.minimumHitSize)
                            .padding(.bottom, theme.layout.primaryNavigationBottomGap)
                            .overlay(alignment: .bottom) {
                                if selected == mode {
                                    Rectangle().fill(Color(nsColor: theme.color(.selectionRing))).frame(height: theme.layout.primaryNavigationIndicatorWidth)
                                }
                            }
                    }
                    .buttonStyle(MatteButtonStyle(.flat, theme: theme))
                    .accessibilityAddTraits(selected == mode ? [.isSelected] : [])
                }
                Spacer(minLength: 0)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(nsColor: theme.color(.edge))).frame(height: theme.layout.hairlineWidth)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
