import BmuxCore
import Foundation

extension BMUXCLI {
    func userFacingRemotePTYErrorMessage(_ value: Any?) -> String {
        if let error = value as? Error {
            return userFacingRemotePTYErrorMessage(String(describing: error))
        }
        return userFacingRemotePTYErrorMessage(debugString(value) ?? "unknown error")
    }

    func userFacingRemotePTYErrorMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        // These aliases are a CLI compatibility policy, not app disclosure policy.
        if lowered.contains("pty.write.notification") || lowered.contains("pty.resize.notification") {
            return RemotePTYFailure.unsupportedDaemon.rawValue
        }
        let failure = RemotePTYFailure(sanitizing: trimmed)
        guard failure == .operationFailed else { return failure.rawValue }
        // Surface the daemon's PTY-allocation diagnostic verbatim (it names the
        // failing device and the devpts/ptmxmode cause) instead of collapsing it
        // into a generic message. Key off the daemon's stable marker only, so an
        // unrelated error that merely mentions a device path is not leaked. The
        // peer branches in this CLI helper return plain English, so this branch
        // does too. See issue #5185.
        if lowered.contains("could not allocate a remote pty") {
            return trimmed
        }
        return failure.rawValue
    }
}
