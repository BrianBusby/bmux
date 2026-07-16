import SwiftUI

/// Corner "Pro" badge in the sidebar footer: renders the active
/// ``ProBadgeStyle`` (Debug > Pro Badge Style switches variants). The
/// sidebar footer keeps the badge visible but disables the upgrade action.
struct SidebarProBadge: View {
    var body: some View {
        ProBadgeView(isUpgradeActionEnabled: false)
    }
}
