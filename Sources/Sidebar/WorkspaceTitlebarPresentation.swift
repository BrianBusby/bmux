import SwiftUI
import BmuxAppKitSupportUI
import BmuxFoundation

/// Presents the centered window title and trailing build badge without owning window actions.
struct WorkspaceTitlebarPresentation: View {
    @Environment(\.bmuxGlobalFontMagnificationPercent) private var fontMagnificationPercent
    let directory: String?
    let title: String
    let buildNumber: String?
    let reservedControlWidth: CGFloat
    let theme: MatteTheme

    var body: some View {
        HStack(spacing: theme.layout.titlebarContentGap) {
            if let directory {
                DetachedFolderDragIcon(directory: directory, tintColor: theme.color(.textSecondary))
                    .frame(width: theme.layout.iconSize, height: theme.layout.iconSize)
            }
            Text(title)
                .matteTypography(.windowTitle, theme: theme, pointSize: magnifiedSize(.windowTitle))
                .foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
                .lineLimit(1)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, reservedControlWidth)
        .overlay(alignment: .trailing) {
            if let buildNumber {
                Text(buildNumber)
                    .matteTypography(.buildBadge, theme: theme, pointSize: magnifiedSize(.buildBadge))
                    .foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
                    .lineLimit(1)
                    .padding(theme.layout.titlebarBadgePadding)
                    .background(Capsule(style: .continuous).fill(Color(nsColor: theme.color(.chip))))
                    .overlay(Capsule(style: .continuous)
                        .stroke(Color(nsColor: theme.color(.edge)), lineWidth: theme.layout.hairlineWidth))
                    .padding(.trailing, theme.layout.titlebarTrailingInset)
                    .allowsHitTesting(false)
                    .accessibilityLabel(Text(String(
                        format: String(localized: "titlebar.buildIndicator.accessibilityLabel", defaultValue: "Build %@"),
                        locale: .current, buildNumber)))
            }
        }
    }

    private func magnifiedSize(_ role: MatteTypographyRole) -> Double {
        GlobalFontMagnification.scaledSize(theme.typography(role).pointSize, percent: fontMagnificationPercent)
    }

}
