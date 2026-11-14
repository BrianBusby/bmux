import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

@main
struct PlanFactualProbe {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            throw NSError(domain: "PlanFactualProbe", code: 1)
        }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: URL(fileURLWithPath: arguments[1]))
        let response = try await client.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: arguments[2])
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        print(String(decoding: try encoder.encode(response), as: UTF8.self))
    }
}
