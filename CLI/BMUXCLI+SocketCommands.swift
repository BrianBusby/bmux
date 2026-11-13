import Foundation

extension BMUXCLI {
    func sendV1Command(_ command: String, client: SocketClient) throws -> String {
        let response = try client.send(command: command)
        if response.hasPrefix("ERROR:") {
            throw CLIError(message: response)
        }
        return response
    }

}
