import Foundation

struct CLIProvenanceResolvedTarget: Equatable {
    let requestedPath: String
    let absolutePath: String
    let repositoryRoot: String
    let relativePath: String
}
