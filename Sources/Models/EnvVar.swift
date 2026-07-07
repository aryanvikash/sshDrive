import Foundation

/// A user-managed environment variable, exported to `~/.zshrc`.
struct EnvVar: Identifiable, Codable, Hashable {
    var id = UUID()
    var key: String
    var value: String

    /// Heuristic: does the key look like it holds a secret? Drives UI masking.
    var isSecret: Bool {
        let needles = ["TOKEN", "SECRET", "KEY", "PASSWORD", "PASSWD", "PASS",
                       "CREDENTIAL", "PRIVATE", "API"]
        let upper = key.uppercased()
        return needles.contains { upper.contains($0) }
    }
}
