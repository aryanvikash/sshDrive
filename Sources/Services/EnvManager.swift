import Foundation

/// Turns managed environment variables into `export KEY='value'` lines.
/// Writing them to `~/.zshrc` is handled by `ShellConfigManager`.
enum EnvManager {
    /// Normalize a user-typed key into a valid shell identifier (letters, digits,
    /// underscore; not starting with a digit). Case is preserved.
    static func sanitizeKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        var chars = trimmed.map { ch -> Character in
            (ch.isLetter || ch.isNumber || ch == "_") ? ch : "_"
        }
        while let first = chars.first, first.isNumber { chars.removeFirst() }
        return String(chars)
    }

    /// `export KEY='value'` lines for every variable (de-duped by key).
    static func lines(from vars: [EnvVar]) -> [String] {
        var seen = Set<String>()
        var lines: [String] = []
        for variable in vars {
            let key = sanitizeKey(variable.key)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            lines.append("export \(key)=\(ShellConfigManager.quote(variable.value))")
        }
        return lines
    }
}
