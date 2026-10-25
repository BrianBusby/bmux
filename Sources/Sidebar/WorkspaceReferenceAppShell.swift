import SwiftUI
import BmuxAppKitSupportUI

/// Presents the continuous matte base and sidebar/main gutter without owning their state.
struct WorkspaceReferenceAppShell<Rail: View, Content: View, HeaderAction: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let showsRail: Bool
    @ViewBuilder let rail: () -> Rail
    @ViewBuilder let content: () -> Content
    @ViewBuilder let headerAction: () -> HeaderAction

    init(showsRail: Bool = true, @ViewBuilder rail: @escaping () -> Rail,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder headerAction: @escaping () -> HeaderAction) {
        self.showsRail = showsRail
        self.rail = rail
        self.content = content
        self.headerAction = headerAction
    }

    var body: some View {
        let theme = MatteTheme(colorScheme: colorScheme)
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: theme.layout.brandHeaderContentGap) {
                        Text("bmux")
                            .matteTypography(.wordmark, theme: theme)
                            .foregroundStyle(Color(nsColor: theme.color(.textPrimary)))
                        Text("✳").font(.system(size: theme.layout.brandDecorationSize)).foregroundStyle(Color(nsColor: theme.color(.sage)))
                        Text("CompanyCam").matteTypography(.body, theme: theme).foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
                    }
                    Spacer()
                    headerAction()
                }
                .padding(.horizontal, theme.layout.brandHeaderHorizontalInset)
                .frame(height: theme.layout.brandHeaderHeight)
                .offset(y: theme.layout.brandHeaderVerticalOffset)

                GeometryReader { geometry in
                    HStack(spacing: theme.layout.windowGutter) {
                        if showsRail {
                            rail()
                                .frame(width: min(theme.layout.sidebarMaximumWidth, max(theme.layout.sidebarMinimumWidth, geometry.size.width * theme.layout.sidebarPreferredFraction)))
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        content()
                            .padding(.top, theme.layout.mainPanelTopInset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(.horizontal, theme.layout.windowGutter)
            .padding(.bottom, theme.layout.windowGutter)
            .padding(.top, theme.layout.shellTopInset)
        }
        .modifier(TerminalBackdropSurface(role: .base, theme: theme))
    }
}
