import BmuxMobileShellModel

@MainActor
final class StaticIdentityProvider: MobileIdentityProviding {
    var currentUserID: String?

    init(userID: String?) {
        self.currentUserID = userID
    }
}
