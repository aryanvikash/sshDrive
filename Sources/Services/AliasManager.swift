import Foundation

/// Turns commands that have an alias into `alias name='command'` lines.
/// Writing them to `~/.zshrc` is handled by `ShellConfigManager`.
enum AliasManager {
    /// Normalize a user-typed alias into a safe shell alias name.
    static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let allowed = trimmed.map { ch -> Character in
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == "." { return ch }
            return "-"
        }
        return String(allowed)
    }

    /// `alias name='command'` lines for every aliased command (de-duped by name).
    static func lines(from nodes: [DriveNode]) -> [String] {
        var seen = Set<String>()
        var lines: [String] = []
        for (name, command) in collect(nodes) where !seen.contains(name) {
            seen.insert(name)
            lines.append("alias \(name)=\(ShellConfigManager.quote(command))")
        }
        return lines
    }

    private static func collect(_ nodes: [DriveNode]) -> [(name: String, command: String)] {
        var out: [(String, String)] = []
        func walk(_ list: [DriveNode]) {
            for node in list {
                if node.isFolder { walk(node.children ?? []); continue }
                let name = sanitize(node.alias)
                let command = node.command.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, !command.isEmpty { out.append((name, command)) }
            }
        }
        walk(nodes)
        return out
    }
}
