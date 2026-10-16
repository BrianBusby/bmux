import BmuxFoundation
import Foundation
import BMUXAgentLaunch
import Darwin

/// Coordinates cancellation with `Process.run()`: Foundation raises an
/// Objective-C exception if termination APIs touch a task before launch.
/// `@unchecked Sendable` is safe here because all mutable state is protected by `lock`.
final class ProcessTerminationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didLaunch = false
    private var didFinish = false
    private var terminationRequested = false

    func requestTermination() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return false }
        terminationRequested = true
        return didLaunch
    }

    func markLaunched() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return false }
        didLaunch = true
        return terminationRequested
    }

    func markFinished() {
        lock.lock()
        defer { lock.unlock() }
        didFinish = true
    }
}

private actor OpenCodeVersionProbeCache {
    private var valuesByKey: [String: Bool] = [:]

    func value(for key: String) -> Bool? {
        valuesByKey[key]
    }

    func store(_ value: Bool, for key: String) {
        valuesByKey[key] = value
    }
}

enum AgentForkSupport {
    static let minimumOpenCodeForkVersion = SemanticVersion(major: 1, minor: 14, patch: 50)
    private static let commandOutputTimeoutNanoseconds: Int64 = 3_000_000_000
    private static let commandTerminateTimeoutNanoseconds: Int64 = 500_000_000
    private static let openCodeVersionProbeCache = OpenCodeVersionProbeCache()

    static func supportsFork(
        snapshot: SessionRestorableAgentSnapshot,
        isRemoteContext: Bool = false
    ) async -> Bool {
        guard snapshot.forkCommand != nil else { return false }
        if isRemoteContext,
           snapshot.forkStartupInput(allowLauncherScript: false) == nil {
            return false
        }
        guard snapshot.kind == .opencode else { return true }
        if snapshot.launchCommand?.launcher == "omo" {
            return true
        }
        if isRemoteContext {
            return true
        }
        guard let probe = AgentResumeCommandBuilder.openCodeVersionProbe(
            launchCommand: snapshot.launchCommand
        ) else {
            return false
        }
        let workingDirectory = openCodeProbeWorkingDirectory(snapshot: snapshot)
        switch localOpenCodeVersionProbeDecision(
            probe: probe,
            workingDirectory: workingDirectory
        ) {
        case .run:
            break
        case .skipRemoteLikeContext:
            return true
        case .rejectMissingExecutable:
            return false
        }
        let cacheKey = openCodeVersionProbeCacheKey(
            probe: probe,
            environment: snapshot.launchCommand?.environment,
            workingDirectory: workingDirectory
        )
        if let cached = await openCodeVersionProbeCache.value(for: cacheKey) {
            return cached
        }
        guard let output = await commandOutput(
            executable: probe.executable,
            arguments: probe.arguments,
            environment: snapshot.launchCommand?.environment,
            workingDirectory: workingDirectory
        ) else {
            return false
        }
        let supportsFork = openCodeVersionSupportsFork(output)
        await openCodeVersionProbeCache.store(supportsFork, for: cacheKey)
        return supportsFork
    }

    static func openCodeVersionSupportsFork(_ output: String) -> Bool {
        guard let version = SemanticVersion.first(in: output) else {
            return false
        }
        return version >= minimumOpenCodeForkVersion
    }

    private static func openCodeVersionProbeCacheKey(
        probe: (executable: String, arguments: [String]),
        environment: [String: String]?,
        workingDirectory: String?
    ) -> String {
        let processEnvironment = processEnvironmentForOpenCodeProbe(environment: environment)
        let relevantEnvironmentKeys = [
            "PATH",
            "OPENCODE_BIN",
            "OPENCODE_CONFIG_DIR"
        ]
        let environmentParts = relevantEnvironmentKeys.map { key in
            "\(key)=\(processEnvironment[key] ?? "")"
        }
        return ([probe.executable] + probe.arguments + environmentParts + ["cwd=\(workingDirectory ?? "")"])
            .joined(separator: "\u{1f}")
    }

    private static func commandOutput(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: String?
    ) async -> String? {
        await OpenCodeProbeCommandOutput(
            executable: executable,
            arguments: arguments,
            environment: processEnvironmentForOpenCodeProbe(environment: environment),
            workingDirectory: localDirectoryURL(path: workingDirectory),
            timeout: .nanoseconds(commandOutputTimeoutNanoseconds),
            terminationGrace: .nanoseconds(commandTerminateTimeoutNanoseconds)
        ).run()
    }

    static func processEnvironmentForOpenCodeProbe(
        environment: [String: String]?,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var processEnvironment = sanitizedBaseEnvironmentForOpenCodeProbe(baseEnvironment)
        if let environment {
            let selectedEnvironment = AgentLaunchEnvironmentPolicy.selectedEnvironment(from: environment)
            for (key, value) in selectedEnvironment {
                processEnvironment[key] = value
            }
        }
        if let path = environment?["PATH"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            processEnvironment["PATH"] = path
        } else if processEnvironment["PATH"] == nil {
            processEnvironment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        return processEnvironment
    }

    private static func sanitizedBaseEnvironmentForOpenCodeProbe(_ environment: [String: String]) -> [String: String] {
        let safeBaseKeys = [
            "HOME",
            "LANG",
            "LC_ALL",
            "LC_CTYPE",
            "LOGNAME",
            "PATH",
            "TMPDIR",
            "USER"
        ]
        var processEnvironment: [String: String] = [:]
        for key in safeBaseKeys {
            guard let value = environment[key],
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            processEnvironment[key] = value
        }
        let selectedEnvironment = AgentLaunchEnvironmentPolicy.selectedEnvironment(from: environment)
        for (key, value) in selectedEnvironment {
            processEnvironment[key] = value
        }
        return processEnvironment
    }

    private static func openCodeProbeWorkingDirectory(snapshot: SessionRestorableAgentSnapshot) -> String? {
        normalized(snapshot.launchCommand?.workingDirectory) ?? normalized(snapshot.workingDirectory)
    }

    private enum LocalOpenCodeVersionProbeDecision {
        case run
        case skipRemoteLikeContext
        case rejectMissingExecutable
    }

    private static func localOpenCodeVersionProbeDecision(
        probe: (executable: String, arguments: [String]),
        workingDirectory: String?
    ) -> LocalOpenCodeVersionProbeDecision {
        if let workingDirectory, localDirectoryURL(path: workingDirectory) == nil {
            return .skipRemoteLikeContext
        }
        if probe.executable.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: probe.executable)
                ? .run
                : .rejectMissingExecutable
        }
        return .run
    }

    private static func localDirectoryURL(path: String?) -> URL? {
        guard let path = normalized(path) else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
