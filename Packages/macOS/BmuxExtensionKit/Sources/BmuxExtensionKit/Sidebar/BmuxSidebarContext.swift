import Foundation

/// Current sidebar state delivered by BMUX to a sidebar extension.
public struct BmuxSidebarContext: Sendable {
    /// Latest workspace snapshot filtered to the permissions granted by the user.
    public let snapshot: BmuxSidebarSnapshot

    /// Read scopes BMUX granted for this snapshot.
    public let grantedReadScopes: Set<BmuxExtensionScope>

    /// Host actions BMUX will currently accept from this extension.
    public let grantedActionScopes: Set<BmuxExtensionActionScope>

    /// Typed command channel back to BMUX.
    public let host: BmuxSidebarHost

    @MainActor
    public init(
        snapshot: BmuxSidebarSnapshot,
        grantedReadScopes: Set<BmuxExtensionScope>? = nil,
        grantedActionScopes: Set<BmuxExtensionActionScope>? = nil,
        host: BmuxSidebarHost
    ) {
        self.snapshot = snapshot
        self.grantedReadScopes = grantedReadScopes ?? snapshot.grantedReadScopes
        self.grantedActionScopes = grantedActionScopes ?? snapshot.grantedActionScopes
        self.host = host
    }
}
