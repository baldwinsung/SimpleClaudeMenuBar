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
            return "Couldn't find the `claude` CLI on your PATH."
        case .nonZeroExit(let code, let output):
            let snippet = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return "claude exited with code \(code).\(snippet.isEmpty ? "" : "\n\(snippet.prefix(200))")"
        }
    }
}

/// Runs `claude -p "/usage"` and returns its combined stdout/stderr.
enum UsageFetcher {
    /// Runs through a login shell so the user's PATH (e.g. Homebrew) is loaded,
    /// since a GUI .app launches with a minimal environment.
    static func run(timeout: TimeInterval) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", #"claude -p "/usage""#]

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
}
