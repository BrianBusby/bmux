import Foundation

protocol KeychainSecretStoreBackend: Sendable {
    func read(service: String, account: String) async throws -> String?
    func write(_ value: String, service: String, account: String) async throws
    func delete(service: String, account: String) async throws
}
