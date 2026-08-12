import BmuxSettings
import Foundation
import Observation

/// `@Observable` view-model that projects one ``KeychainSecretKey`` value into
/// SwiftUI-bindable state.
///
/// Same shape as ``SecretValueModel`` but bound to ``KeychainSecretStore``.
/// Set / reset failures populate ``lastWriteError`` and are pushed into the
/// injected ``SettingsErrorLog`` so the UI surfaces them centrally.
@MainActor
@Observable
public final class KeychainSecretValueModel {
    /// The most recently observed secret. SwiftUI views read this synchronously.
    public private(set) var current: String

    /// Error from the most recent set/reset attempt, or `nil`.
    public private(set) var lastWriteError: Error?

    private let store: KeychainSecretStore
    private let key: KeychainSecretKey
    private let errorLog: SettingsErrorLog
    @ObservationIgnored private let makeStream: () -> AsyncStream<String>

    /// Owns the change-stream subscription and cancels it when this model deallocates.
    @ObservationIgnored private let observation = SettingReadDriver<String>()

    /// Creates a model bound to ``key`` in ``store``.
    ///
    /// - Parameters:
    ///   - store: The Keychain store to read from and write to.
    ///   - key: The secret to observe.
    ///   - errorLog: Global log that write failures are pushed into.
    public convenience init(
        store: KeychainSecretStore,
        key: KeychainSecretKey,
        errorLog: SettingsErrorLog
    ) {
        self.init(
            store: store,
            key: key,
            errorLog: errorLog,
            makeStream: { store.values(for: key) }
        )
    }

    init(
        store: KeychainSecretStore,
        key: KeychainSecretKey,
        errorLog: SettingsErrorLog,
        makeStream: @escaping () -> AsyncStream<String>
    ) {
        self.store = store
        self.key = key
        self.errorLog = errorLog
        self.makeStream = makeStream
        self.current = key.defaultValue
    }

    /// Starts the Keychain change stream for the retained model.
    ///
    /// Idempotent: later calls are ignored by ``SettingReadDriver``.
    public func startObserving() {
        observation.activate(makeStream) { [weak self] value in
            self?.current = value
        }
    }

    /// Persists the secret. The observation stream is the single writer of ``current``.
    ///
    /// - Parameter value: The secret value to persist.
    public func set(_ value: String) {
        let keyID = key.id
        Task { [weak self, store, key] in
            do {
                try await store.set(value, for: key)
                self?.lastWriteError = nil
            } catch {
                self?.lastWriteError = error
                self?.errorLog.record(error, keyID: keyID)
            }
        }
    }

    /// Clears the secret from Keychain.
    public func reset() {
        let keyID = key.id
        Task { [weak self, store, key] in
            do {
                try await store.reset(key)
                self?.lastWriteError = nil
            } catch {
                self?.lastWriteError = error
                self?.errorLog.record(error, keyID: keyID)
            }
        }
    }
}
