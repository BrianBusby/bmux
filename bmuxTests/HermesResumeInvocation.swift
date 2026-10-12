/// One invocation captured by an owned Hermes executable during startup execution.
struct HermesResumeInvocation: Equatable {
    let executable: String
    let directory: String
    let baseURL: String
    let codexHome: String
    let arguments: [String]
}
