extension ShellContractProcess {
    struct Result: Sendable {
        let status: Int32
        let terminatedNormally: Bool
        let stdout: String
        let stderr: String
    }
}
