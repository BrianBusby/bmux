public import Foundation

/// Typed read/write/observe access to secret strings stored in macOS Keychain.
///
/// The store is an `actor`; reads, writes, and resets are async. It accepts
/// only ``KeychainSecretKey`` values. Each key is stored as a generic-password
/// item under this store's Keychain service, so the app can share settings
/// secrets across tagged builds in the same release channel.
///
/// ```swift
/// let store = KeychainSecretStore(
///     service: KeychainSecretStore.serviceName(bundleIdentifier: Bundle.main.bundleIdentifier)
/// )
/// try await store.set("lin_api_...", for: catalog.integrations.linearAPIKey)
/// ```
public actor KeychainSecretStore {
    /// Posted (in process) after any Keychain secret is written or cleared.
    public static let didChangeNotification = Notification.Name("bmux.keychainSecretStoreDidChange")

    /// `userInfo` key under which ``didChangeNotification`` carries the changed key id.
    public static let changedKeyIDKey = "keyID"

    /// The Keychain service this store writes under.
    public nonisolated let service: String

    private let backend: any KeychainSecretStoreBackend

    /// Creates a Keychain-backed store.
    /// - Parameter service: Keychain service name used to namespace stored secrets.
    public init(service: String) {
        self.init(service: service, backend: SystemKeychainSecretStoreBackend())
    }

    init(service: String, backend: any KeychainSecretStoreBackend) {
        self.service = service
        self.backend = backend
    }

    /// The standard Keychain service name for bmux settings secrets.
    /// - Parameter bundleIdentifier: The app bundle identifier.
    /// - Returns: A stable service string for settings secrets.
    public static func serviceName(bundleIdentifier: String?) -> String {
        "\(settingsSecretBundleIdentifier(bundleIdentifier)).settings-secrets"
    }

    private static func settingsSecretBundleIdentifier(_ bundleIdentifier: String?) -> String {
        guard let identifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifier.isEmpty else {
            return "com.bmuxterm.app"
        }
        for channelIdentifier in [
            "com.bmuxterm.app.debug",
            "com.bmuxterm.app.staging",
            "com.bmuxterm.app.nightly",
        ] {
            if identifier == channelIdentifier || identifier.hasPrefix("\(channelIdentifier).") {
                return channelIdentifier
            }
        }
        return identifier
    }

    /// Reads the current secret for `key`.
    ///
    /// - Parameter key: The Keychain-backed setting to read.
    /// - Returns: The stored non-empty value, or ``KeychainSecretKey/defaultValue`` when absent or empty.
    /// - Throws: ``KeychainSecretStoreError`` when the backing Keychain read fails.
    public func value(for key: KeychainSecretKey) async throws -> String {
        guard let raw = try await backend.read(service: service, account: key.account),
              let normalized = Self.normalized(raw) else {
            return key.defaultValue
        }
        return normalized
    }

    /// Whether a non-empty Keychain item exists for `key`.
    ///
    /// This inspects the stored item directly and ignores
    /// ``KeychainSecretKey/defaultValue``.
    /// - Parameter key: The Keychain-backed setting to inspect.
    /// - Returns: `true` when a non-empty item is stored for `key`.
    public func hasValue(for key: KeychainSecretKey) async -> Bool {
        guard let raw = try? await backend.read(service: service, account: key.account) else {
            return false
        }
        return Self.normalized(raw) != nil
    }

    /// Writes `value` to Keychain, or clears it when empty after newline-trimming.
    ///
    /// - Parameters:
    ///   - value: The secret value to store.
    ///   - key: The Keychain-backed setting to write.
    /// - Throws: ``KeychainSecretStoreError`` when the backing Keychain write or delete fails.
    public func set(_ value: String, for key: KeychainSecretKey) async throws {
        let normalized = value.trimmingCharacters(in: .newlines)
        if normalized.isEmpty {
            try await reset(key)
            return
        }
        try await backend.write(normalized, service: service, account: key.account)
        postChange(for: key)
    }

    /// Deletes the Keychain item for `key` when present.
    ///
    /// - Parameter key: The Keychain-backed setting to clear.
    /// - Throws: ``KeychainSecretStoreError`` when the backing Keychain delete fails.
    public func reset(_ key: KeychainSecretKey) async throws {
        try await backend.delete(service: service, account: key.account)
        postChange(for: key)
    }

    /// An `AsyncStream` yielding the current secret and every later change.
    ///
    /// The first element is the current value; subsequent elements arrive when
    /// ``didChangeNotification`` fires for this key. Buffering is
    /// `.bufferingNewest(1)`.
    /// - Parameter key: The Keychain-backed setting to observe.
    /// - Returns: A stream of observed values for `key`.
    public nonisolated func values(for key: KeychainSecretKey) -> AsyncStream<String> {
        AsyncStream<String>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let (signals, signalContinuation) = AsyncStream<Void>.makeStream(
                bufferingPolicy: .bufferingNewest(1)
            )

            let observer = NotificationObserverToken(
                NotificationCenter.default.addObserver(
                    forName: KeychainSecretStore.didChangeNotification,
                    object: nil,
                    queue: nil
                ) { [weak self] note in
                    if let changedID = note.userInfo?[KeychainSecretStore.changedKeyIDKey] as? String,
                       changedID != key.id {
                        return
                    }
                    guard self != nil else { return }
                    signalContinuation.yield(())
                }
            )

            let drainTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                var lastYielded = (try? await self.value(for: key)) ?? key.defaultValue
                continuation.yield(lastYielded)

                for await _ in signals {
                    if Task.isCancelled { break }
                    let current = (try? await self.value(for: key)) ?? key.defaultValue
                    if current != lastYielded {
                        lastYielded = current
                        continuation.yield(current)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                drainTask.cancel()
                signalContinuation.finish()
                observer.remove()
            }
        }
    }

    private func postChange(for key: KeychainSecretKey) {
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: nil,
            userInfo: [Self.changedKeyIDKey: key.id]
        )
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .newlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
