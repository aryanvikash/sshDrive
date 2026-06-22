import AppKit

struct TerminalChoice: Identifiable, Hashable {
    let id: String      // bundle identifier
    let name: String    // display name
}

/// The terminals Shell Drive knows how to target, plus availability helpers.
enum TerminalCatalog {
    static let all: [TerminalChoice] = [
        .init(id: "com.apple.Terminal",     name: "Terminal"),
        .init(id: "com.googlecode.iterm2",  name: "iTerm"),
        .init(id: "dev.warp.Warp-Stable",   name: "Warp"),
        .init(id: "com.mitchellh.ghostty",  name: "Ghostty"),
        .init(id: "net.kovidgoyal.kitty",   name: "kitty"),
        .init(id: "com.github.wez.wezterm", name: "WezTerm"),
        .init(id: "io.alacritty",           name: "Alacritty"),
        .init(id: "co.zeit.hyper",          name: "Hyper"),
    ]

    static let defaultID = "com.apple.Terminal"

    static let bundleIDs: Set<String> = Set(all.map(\.id))

    static func name(for id: String) -> String {
        all.first { $0.id == id }?.name ?? "Terminal"
    }

    static func isInstalled(_ id: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
    }

    /// Installed terminals first, so the user sees what they actually have.
    static var sortedByAvailability: [TerminalChoice] {
        all.sorted { isInstalled($0.id) && !isInstalled($1.id) }
    }
}

/// Persisted preference for which terminal to target.
enum TerminalPreference {
    private static let key = "defaultTerminal"

    static var bundleID: String {
        get { UserDefaults.standard.string(forKey: key) ?? TerminalCatalog.defaultID }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
