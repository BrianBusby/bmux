import Darwin
import Foundation
import Testing

/// Owns the real socket and interactive-shell home for one disabled-git-watch contract.
final class NoGitWatchShellFixture {
    let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("no-git-watch-\(UUID().uuidString)")
    private var descriptor: Int32 = -1
    private var socketPath: String { root.appendingPathComponent("socket").path }

    init() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try bindSocket()
    }

    deinit {
        if descriptor >= 0 { Darwin.close(descriptor) }
        try? FileManager.default.removeItem(at: root)
    }

    func run(shell: String) async throws -> String {
        let integration = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/shell-integration")
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "TERM": "xterm-256color",
            "SHELL": "/bin/\(shell)", "USER": NSUserName(), "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "BMUX_NO_GIT_WATCH": "1", "BMUX_SOCKET_PATH": socketPath,
            "BMUX_TAB_ID": "22222222-2222-2222-2222-222222222222",
            "BMUX_PANEL_ID": "22222222-2222-2222-2222-222222222222",
        ]
        let arguments: [String]
        if shell == "bash" {
            let rcfile = root.appendingPathComponent(".bashrc")
            try ". \"\(integration.appendingPathComponent("bmux-bash-integration.bash").path)\"\n"
                .write(to: rcfile, atomically: true, encoding: .utf8)
            arguments = ["--noprofile", "--rcfile", rcfile.path, "-i", "-c", command(prompt: "_bmux_prompt_command")]
        } else {
            try #require(shell == "zsh")
            let zdotdir = root.appendingPathComponent("zdotdir")
            try FileManager.default.createDirectory(at: zdotdir, withIntermediateDirectories: true)
            try "\n".write(to: zdotdir.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
            environment["ZDOTDIR"] = integration.path
            environment["BMUX_ZSH_ZDOTDIR"] = zdotdir.path
            environment["BMUX_SHELL_INTEGRATION"] = "1"
            environment["BMUX_SHELL_INTEGRATION_DIR"] = integration.path
            arguments = ["-i", "-c", command(prompt: "_bmux_precmd")]
        }
        let result = try await ShellContractProcess(root: root).run(executable: "/bin/\(shell)", arguments: arguments, environment: environment)
        #expect(result.status == 0, "\(result.stderr)")
        return result.stdout
    }

    private func command(prompt: String) -> String {
        let repoA = root.appendingPathComponent("repo-a"), repoB = root.appendingPathComponent("repo-b")
        let log = root.appendingPathComponent("send.log")
        return """
        mkdir -p "\(repoA.path)/.git" "\(repoB.path)/.git"
        printf '%s\\n' 'ref: refs/heads/main' > "\(repoA.path)/.git/HEAD"
        printf '%s\\n' 'ref: refs/heads/feature' > "\(repoB.path)/.git/HEAD"
        : > "\(log.path)"
        _bmux_send() { printf '%s\\n' "$1" >> "\(log.path)"; }
        cd "\(repoA.path)"
        _BMUX_TTY_REPORTED=1
        _BMUX_PORTS_LAST_RUN=$(_bmux_now)
        _BMUX_PWD_LAST_PWD="$PWD"
        _BMUX_GIT_HEAD_LAST_PWD="$PWD"
        _BMUX_GIT_HEAD_PATH="$PWD/.git/HEAD"
        _BMUX_GIT_HEAD_SIGNATURE="$(_bmux_git_head_signature "$_BMUX_GIT_HEAD_PATH")"
        printf '%s\\n' 'ref: refs/heads/old-cleared' > "$_BMUX_GIT_HEAD_PATH"
        cd "\(repoB.path)"
        _BMUX_PWD_LAST_PWD="$PWD"
        _BMUX_LAST_PR_ACTION="checkout"
        _BMUX_LAST_PR_TARGET="feature"
        \(prompt)
        printf 'HEAD_PATH=%s\\n' "$_BMUX_GIT_HEAD_PATH"
        printf 'HEAD_LAST_PWD=%s\\n' "$_BMUX_GIT_HEAD_LAST_PWD"
        printf 'LAST_PR_ACTION=%s\\n' "$_BMUX_LAST_PR_ACTION"
        printf 'LOG<<EOF\\n'
        cat "\(log.path)"
        printf 'EOF\\n'
        wait
        """
    }

    private func bindSocket() throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        try #require(socketPath.utf8.count < capacity, "Owned socket path exceeds sockaddr_un.sun_path")
        descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        socketPath.withCString { source in
            withUnsafeMutablePointer(to: &address.sun_path) { pointer in
                UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: CChar.self).update(from: source, count: socketPath.utf8.count + 1)
            }
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0, Darwin.listen(descriptor, 1) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    }
}
