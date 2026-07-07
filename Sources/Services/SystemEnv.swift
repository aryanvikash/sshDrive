import Foundation

/// Reads the *login shell's* environment — what a new terminal would actually
/// see — by running `$SHELL -lic env`. (A GUI app's own `ProcessInfo`
/// environment is minimal and wouldn't reflect `~/.zshrc` exports.)
enum SystemEnv {
    /// Snapshot the current shell environment, sorted by key. Runs a shell, so
    /// call it off the main thread.
    static func snapshot() -> [EnvVar] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lic", "env"]     // login + interactive → sources rc files

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()          // discard job-control noise

        do { try process.run() } catch { return [] }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return parse(String(data: data, encoding: .utf8) ?? "")
    }

    /// Parse `env` output into variables. Lines without a leading `KEY=` are
    /// treated as continuations of the previous (multi-line) value.
    static func parse(_ text: String) -> [EnvVar] {
        var result: [EnvVar] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if let eq = line.firstIndex(of: "="), isValidKey(String(line[..<eq])) {
                result.append(EnvVar(key: String(line[..<eq]),
                                     value: String(line[line.index(after: eq)...])))
            } else if !result.isEmpty {
                result[result.count - 1].value += "\n" + line
            }
        }
        return result.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    private static func isValidKey(_ key: String) -> Bool {
        guard let first = key.first, first.isLetter || first == "_" else { return false }
        return key.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
