import BmuxFoundation
import Foundation
import Testing

/// Owns a CLI subprocess and a strict, isolated workspace/surface protocol fixture.
final class WorkspaceFallbackFixture {
    enum Entry: CaseIterable, Sendable { case flash, notification }
    enum Scenario: CaseIterable, Sendable {
        case staleAmbient, noAmbient, validAmbient, ttyRecovery, explicitValid, explicitInvalid
        case window, noCurrent, currentError
    }

    let root: URL
    let current = "11111111-1111-1111-1111-111111111111"
    let ambient = "22222222-2222-2222-2222-222222222222"
    let tty = "33333333-3333-3333-3333-333333333333"
    let explicit = "44444444-4444-4444-4444-444444444444"
    let windowWorkspace = "55555555-5555-5555-5555-555555555555"
    let stale = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
    let staleSurface = "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
    let window = "66666666-6666-6666-6666-666666666666"

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("ws-fallback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(cli: String, entry: Entry, scenario: Scenario) async throws {
        let surfaces = Dictionary(uniqueKeysWithValues: [current, ambient, tty, explicit, windowWorkspace].enumerated().map {
            ($0.element, "77777777-7777-7777-7777-\(String(format: "%012d", $0.offset + 1))")
        })
        let target: String
        switch scenario {
        case .validAmbient: target = ambient
        case .ttyRecovery: target = tty
        case .explicitValid: target = explicit
        case .window: target = windowWorkspace
        default: target = current
        }
        let expectedSurface = try #require(surfaces[target])
        let fails = [.explicitInvalid, .noCurrent, .currentError].contains(scenario)
        let socketPath = root.appendingPathComponent("socket").path
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "BMUX_SOCKET_PATH": socketPath, "BMUX_CLI_SENTRY_DISABLED": "1",
            "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ]
        if scenario != .noAmbient {
            environment["BMUX_WORKSPACE_ID"] = scenario == .validAmbient ? ambient : stale
            environment["BMUX_SURFACE_ID"] = scenario == .validAmbient ? surfaces[ambient] : staleSurface
        }
        if scenario == .ttyRecovery { environment["BMUX_CLI_TTY_NAME"] = "fallback-tty" }
        var arguments = entry == .flash ? ["trigger-flash"] : ["notify", "--surface", "0", "--title", "Routing", "--body", "Body"]
        if scenario == .explicitValid || scenario == .explicitInvalid {
            arguments += ["--workspace", scenario == .explicitValid ? explicit : stale]
            if entry == .flash { arguments += ["--surface", scenario == .explicitValid ? "0" : staleSurface] }
        }
        if scenario == .window { arguments += ["--window", window] }

        let current = current, stale = stale, staleSurface = staleSurface, tty = tty, window = window
        let windowWorkspace = windowWorkspace
        let server = CLISocketFixture(path: socketPath) { line in
            if line.hasPrefix("notify_target ") {
                try #require(!fails && entry == .notification)
                try #require(line == "notify_target \(target) \(expectedSurface) Routing||Body", "Wrong notification target: \(line)")
                return "OK"
            }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            let method = try #require(request["method"] as? String)
            let params = request["params"] as? [String: Any] ?? [:]
            var result: [String: Any] = [:]
            var error: [String: String]?
            switch method {
            case "surface.list":
                let workspace = try #require(params["workspace_id"] as? String)
                if workspace == stale { error = ["code": "not_found", "message": "Workspace not found"] }
                else {
                    let surface = try #require(surfaces[workspace], "Unknown workspace: \(line)")
                    if let requestedWindow = params["window_id"] as? String {
                        try #require(requestedWindow == window && workspace == windowWorkspace)
                    }
                    let hasFocusedDecoy = workspace == target && [.validAmbient, .ttyRecovery].contains(scenario)
                    // Identity is deliberately unfocused; notify still explicitly selects index 0.
                    var listed: [[String: Any]] = [
                        ["id": surface, "ref": "surface:1", "index": 0, "focused": !hasFocusedDecoy],
                    ]
                    if hasFocusedDecoy {
                        listed.append([
                            "id": "88888888-8888-8888-8888-888888888888",
                            "ref": "surface:2", "index": 1, "focused": true,
                        ])
                    }
                    result = ["surfaces": listed]
                }
            case "debug.terminals":
                try #require(scenario == .ttyRecovery && params.isEmpty)
                result = ["terminals": [["tty": "fallback-tty", "workspace_id": tty, "surface_id": surfaces[tty]!]]]
            case "workspace.current":
                if scenario == .window {
                    try #require(params as NSDictionary == ["window_id": window] as NSDictionary)
                    result = ["workspace_id": windowWorkspace]
                } else {
                    try #require(params.isEmpty)
                    if scenario == .currentError { error = ["code": "unavailable", "message": "Selection unavailable"] }
                    else if scenario != .noCurrent { result = ["workspace_id": current] }
                }
            case "surface.trigger_flash":
                try #require(entry == .flash)
                if scenario == .explicitInvalid {
                    try #require(params as NSDictionary == ["workspace_id": stale, "surface_id": staleSurface] as NSDictionary)
                    error = ["code": "not_found", "message": "Workspace not found"]
                } else {
                    try #require(!fails)
                    var expected = ["workspace_id": target, "surface_id": expectedSurface]
                    if scenario == .window { expected["window_id"] = window }
                    try #require(params as NSDictionary == expected as NSDictionary, "Wrong flash target: \(line)")
                }
            default:
                Issue.record("Unexpected command or focus mutation: \(line)")
                error = ["code": "unexpected", "message": method]
            }
            var response: [String: Any] = ["id": id, "ok": error == nil]
            if let error { response["error"] = error } else { response["result"] = result }
            return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
        }
        let runner = CommandRunner(environment: environment)
        let (result, commands) = try await server.capture {
            // Owned files keep socket replies independent of blocking cooperative pipe readers.
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "cli=$1; output=$2; errors=$3; shift 3; exec \"$cli\" \"$@\" </dev/null >\"$output\" 2>\"$errors\"",
                "workspace-fallback", cli, stdout.path, stderr.path,
            ] + arguments, timeout: 5)
        }
        try #require(!result.timedOut && result.executionError == nil)
        let output = try String(contentsOf: stdout, encoding: .utf8)
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == (fails ? 1 : 0), "\(errors); \(commands)")
        #expect(output == (fails ? "" : "OK\n"))
        let mutations = commands.filter { $0.hasPrefix("notify_target ") || $0.contains("surface.trigger_flash") }
        #expect(mutations.count == (!fails || (entry == .flash && scenario == .explicitInvalid) ? 1 : 0))
        if !fails { #expect(errors.isEmpty, "\(errors)") }
        else {
            let message = scenario == .noCurrent ? "No workspace selected" :
                (scenario == .currentError ? "Selection unavailable" : "Workspace not found")
            #expect(errors.contains(message), "\(errors)")
        }
        let currentQueries = commands.filter { $0.contains("workspace.current") }
        #expect(currentQueries.count == ([.staleAmbient, .noAmbient, .window, .noCurrent, .currentError].contains(scenario) ? 1 : 0))
    }
}
