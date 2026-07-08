struct DockTrustRequest: Identifiable, Sendable {
    var id: String { descriptor.fingerprint }
    let descriptor: BmuxActionTrustDescriptor
    let configPath: String
}
