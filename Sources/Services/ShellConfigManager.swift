import Foundation

/// Writes Shell Drive's managed blocks (aliases + env vars) into `~/.zshrc` in a
/// single pass. Each block is delimited by markers; the rest of the file is never
/// touched, and the original is backed up once before the first edit. Doing both
/// blocks together keeps their order stable and avoids redundant rewrites.
enum ShellConfigManager {
    private typealias Markers = (start: String, end: String)

    private static let aliasMarkers: Markers = (
        "# >>> Shell Drive aliases (managed — do not edit) >>>",
        "# <<< Shell Drive aliases (managed — do not edit) <<<")
    private static let envMarkers: Markers = (
        "# >>> Shell Drive env (managed — do not edit) >>>",
        "# <<< Shell Drive env (managed — do not edit) <<<")

    static var rcURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
    }
    static var backupURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc.shelldrive.bak")
    }

    /// Rewrite both managed blocks to match the given lines. Empty arrays remove
    /// the corresponding block entirely. Writes only if the file actually changes.
    /// `rcURL`/`backupURL` are injectable for testing.
    static func sync(aliasLines: [String], envLines: [String],
                     rcURL: URL = ShellConfigManager.rcURL,
                     backupURL: URL = ShellConfigManager.backupURL) {
        let original = (try? String(contentsOf: rcURL, encoding: .utf8)) ?? ""
        var body = original
        body = removeBlock(aliasMarkers, from: body)
        body = removeBlock(envMarkers, from: body)
        body = appendBlock(aliasMarkers, lines: aliasLines, to: body)
        body = appendBlock(envMarkers, lines: envLines, to: body)

        guard body != original else { return }

        let fm = FileManager.default
        if !fm.fileExists(atPath: backupURL.path), fm.fileExists(atPath: rcURL.path) {
            try? fm.copyItem(at: rcURL, to: backupURL)
        }
        try? body.write(to: rcURL, atomically: true, encoding: .utf8)
    }

    /// Single-quote a value for shell, escaping embedded single quotes.
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Block editing

    private static func appendBlock(_ markers: Markers, lines: [String], to text: String) -> String {
        guard !lines.isEmpty else { return text }
        let block = ([markers.start] + lines + [markers.end]).joined(separator: "\n")
        if text.isEmpty { return block + "\n" }
        let separator = text.hasSuffix("\n") ? "" : "\n"
        return text + separator + "\n" + block + "\n"
    }

    /// Remove a marker-delimited block (and a single blank line around it).
    private static func removeBlock(_ markers: Markers, from text: String) -> String {
        guard let start = text.range(of: markers.start),
              let end = text.range(of: markers.end, range: start.upperBound..<text.endIndex)
        else { return text }

        var lower = start.lowerBound
        var upper = end.upperBound
        if upper < text.endIndex, text[upper] == "\n" { upper = text.index(after: upper) }
        if lower > text.startIndex {
            let before = text.index(before: lower)
            if text[before] == "\n" { lower = before }
        }
        var result = text
        result.removeSubrange(lower..<upper)
        return result
    }
}
