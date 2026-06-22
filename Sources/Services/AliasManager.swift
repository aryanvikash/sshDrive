import Foundation

// Keeps a managed block of `alias name='command'` lines in ~/.zshrc in sync with
// the commands that have an alias set. The block is rewritten wholesale on every
// sync, so removing/clearing an alias also removes it from the rc file. The rest
// of the user's .zshrc is never touched (and is backed up once before first edit).
enum AliasManager {
    static let startMarker = "# >>> Shell Drive aliases (managed — do not edit) >>>"
    static let endMarker   = "# <<< Shell Drive aliases (managed — do not edit) <<<"

    static var rcURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
    }
    private static var backupURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc.shelldrive.bak")
    }

    /// Normalize a user-typed alias into a safe shell alias name.
    static func sanitize(_ raw: String) -> String {
        let lowered = raw.trimmingCharacters(in: .whitespaces)
        let allowed = lowered.map { ch -> Character in
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == "." { return ch }
            if ch == " " { return "-" }
            return "-"
        }
        return String(allowed)
    }

    /// Collect (alias, command) pairs from live (non-trashed) command nodes.
    static func collect(_ nodes: [DriveNode]) -> [(name: String, command: String)] {
        var out: [(String, String)] = []
        func walk(_ list: [DriveNode]) {
            for n in list {
                if n.isFolder { walk(n.children ?? []) }
                else {
                    let a = sanitize(n.alias)
                    let cmd = n.command.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !a.isEmpty && !cmd.isEmpty { out.append((a, cmd)) }
                }
            }
        }
        walk(nodes)
        // De-dupe by name (last one wins), keep stable order.
        var seen = Set<String>()
        var unique: [(String, String)] = []
        for pair in out where !seen.contains(pair.0) { seen.insert(pair.0); unique.append(pair) }
        return unique
    }

    /// Rewrite the managed block in ~/.zshrc to match the current aliases.
    /// Returns true if the file was changed.
    @discardableResult
    static func sync(_ nodes: [DriveNode]) -> Bool {
        let aliases = collect(nodes)
        let fm = FileManager.default
        let existing = (try? String(contentsOf: rcURL, encoding: .utf8)) ?? ""

        // Build the new file contents.
        let block = renderBlock(aliases)
        let stripped = removingBlock(from: existing)
        let newContents: String
        if aliases.isEmpty {
            newContents = stripped                       // no aliases → no block at all
        } else if stripped.isEmpty {
            newContents = block + "\n"
        } else {
            let sep = stripped.hasSuffix("\n") ? "" : "\n"
            newContents = stripped + sep + "\n" + block + "\n"
        }

        guard newContents != existing else { return false }

        // Back up the original once, before our first modification.
        if !fm.fileExists(atPath: backupURL.path), fm.fileExists(atPath: rcURL.path) {
            try? fm.copyItem(at: rcURL, to: backupURL)
        }
        try? newContents.write(to: rcURL, atomically: true, encoding: .utf8)
        return true
    }

    private static func renderBlock(_ aliases: [(name: String, command: String)]) -> String {
        var lines = [startMarker]
        for (name, command) in aliases {
            // Single-quote the command and escape any embedded single quotes.
            let escaped = command.replacingOccurrences(of: "'", with: "'\\''")
            lines.append("alias \(name)='\(escaped)'")
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }

    /// Remove an existing managed block (and trailing blank lines around it).
    private static func removingBlock(from text: String) -> String {
        guard let startRange = text.range(of: startMarker),
              let endRange = text.range(of: endMarker, range: startRange.upperBound..<text.endIndex)
        else { return text }
        var lower = startRange.lowerBound
        var upper = endRange.upperBound
        // Eat a trailing newline after the end marker.
        if upper < text.endIndex, text[upper] == "\n" { upper = text.index(after: upper) }
        // Eat a single blank line immediately before the block.
        if lower > text.startIndex {
            let before = text.index(before: lower)
            if text[before] == "\n" { lower = before }
        }
        var result = text
        result.removeSubrange(lower..<upper)
        return result
    }
}
