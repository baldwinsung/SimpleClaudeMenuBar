import Foundation

enum FetchError: LocalizedError {
    case timedOut
    case noClaudeBinary
    case nonZeroExit(code: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "Timed out running `claude -p /usage`."
        case .noClaudeBinary:
            return "Couldn't find the `claude` CLI. Set its path in defaults key `claudePath`."
        case .nonZeroExit(let code, let output):
            let snippet = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return "claude exited with code \(code).\(snippet.isEmpty ? "" : "\n\(snippet.prefix(200))")"
        }
    }
}

/// Runs `claude -p "/usage"` and returns its combined stdout/stderr.
///
/// The `claude` binary is invoked **directly** (not via a login shell) from a
/// neutral temp directory. This avoids sourcing the user's shell rc files and
/// inheriting a protected working directory — both of which can trigger a
/// macOS privacy prompt (e.g. "would like to access your Documents folder").
enum UsageFetcher {
    private static var cachedPath: String?

    static func run(timeout: TimeInterval) throws -> String {
        let claude = try resolveClaudePath()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claude)
        process.arguments = ["-p", "/usage"]
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        process.environment = environment(for: claude)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw FetchError.noClaudeBinary
        }

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw FetchError.timedOut
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw FetchError.nonZeroExit(code: process.terminationStatus, output: output)
        }
        return output
    }

    /// Locates `claude` without spawning a login shell where possible.
    private static func resolveClaudePath() throws -> String {
        let fm = FileManager.default

        if let override = UserDefaults.standard.string(forKey: "claudePath"),
           fm.isExecutableFile(atPath: override) {
            return override
        }
        if let cached = cachedPath, fm.isExecutableFile(atPath: cached) {
            return cached
        }

        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.claude/local/claude",
            "\(home)/.local/bin/claude",
            "\(home)/.bun/bin/claude",
            "\(home)/.npm-global/bin/claude",
        ]
        for path in candidates where fm.isExecutableFile(atPath: path) {
            cachedPath = path
            return path
        }

        // Last resort: ask a login shell once (may itself prompt, but rarely reached).
        if let resolved = loginShellResolve(), fm.isExecutableFile(atPath: resolved) {
            cachedPath = resolved
            return resolved
        }

        throw FetchError.noClaudeBinary
    }

    private static func loginShellResolve() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (out?.isEmpty == false) ? out : nil
    }

    private static func environment(for claudePath: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let binDir = (claudePath as NSString).deletingLastPathComponent
        let extras = [binDir, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existing = env["PATH"].map { [$0] } ?? []
        env["PATH"] = (extras + existing).joined(separator: ":")
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        return env
    }
}
