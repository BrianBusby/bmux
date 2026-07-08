/// A flavor of the bmux app, used to derive per-flavor socket and marker file paths.
///
/// Stable, nightly, staging, and dev builds each run side by side with isolated control
/// sockets so they never collide. The associated `slug` (when present) further scopes
/// nightly/staging/dev builds that carry a tag in their bundle identifier or `BMUX_TAG`.
public enum SocketPathVariant: Equatable, Sendable {
    /// The shipping release build.
    case stable
    /// A nightly build, optionally tag-scoped by `slug`.
    case nightly(slug: String?)
    /// A staging build, optionally tag-scoped by `slug`.
    case staging(slug: String?)
    /// A local debug/dev build, optionally tag-scoped by `slug`.
    case dev(slug: String?)

    /// The marker file name (within ``BmuxStateDirectory``) that records this
    /// variant's last socket path.
    public var markerFileName: String {
        switch self {
        case .stable:
            return SocketPathMarkerFiles.stableMarkerFileName
        case .nightly(let slug):
            if let slug = Self.sanitizedSlug(slug) {
                return "nightly-\(slug)-last-socket-path"
            }
            return "nightly-last-socket-path"
        case .staging(let slug):
            if let slug = Self.sanitizedSlug(slug) {
                return "staging-\(slug)-last-socket-path"
            }
            return "staging-last-socket-path"
        case .dev(let slug):
            if let slug = Self.sanitizedSlug(slug) {
                return "dev-\(slug)-last-socket-path"
            }
            return "dev-last-socket-path"
        }
    }

    /// The `/tmp` marker file path that records this variant's last socket path.
    public var tmpPath: String {
        switch self {
        case .stable:
            return SocketPathMarkerFiles.stableTmpPath
        case .nightly(let slug):
            if let slug = Self.sanitizedSlug(slug) {
                return "/tmp/bmux-nightly-\(slug)-last-socket-path"
            }
            return "/tmp/bmux-nightly-last-socket-path"
        case .staging(let slug):
            if let slug = Self.sanitizedSlug(slug) {
                return "/tmp/bmux-staging-\(slug)-last-socket-path"
            }
            return "/tmp/bmux-staging-last-socket-path"
        case .dev(let slug):
            if let slug = Self.sanitizedSlug(slug) {
                return "/tmp/bmux-dev-\(slug)-last-socket-path"
            }
            return "/tmp/bmux-dev-last-socket-path"
        }
    }

    /// Whether this is a local debug/dev build.
    public var isDev: Bool {
        if case .dev = self { return true }
        return false
    }

    /// Reduces a tag slug to a filesystem-safe token (letters, digits, `-`, `_`),
    /// or `nil` when nothing safe remains.
    ///
    /// The slug is embedded directly into marker file names and `/tmp` paths, so a
    /// value such as `"../other"` or one containing `/` must not be allowed to
    /// escape the intended namespace. Disallowed characters (including `.`, which
    /// could form `..`) are dropped; an empty result falls back to the no-slug path.
    private static func sanitizedSlug(_ slug: String?) -> String? {
        guard let slug else { return nil }
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let filtered = String(slug.unicodeScalars.filter { allowed.contains(Character($0)) })
        return filtered.isEmpty ? nil : filtered
    }
}
