import AppKit

/// Delivers a command to a terminal in three ways:
/// - `copyToClipboard` — just the clipboard.
/// - `pasteToTerminal` — copy, focus the terminal, synthesize ⌘V (no Return).
/// - `runInTerminal` — open the chosen terminal and execute the command.
///
/// Pasting/running into non-scriptable terminals synthesizes keystrokes, which
/// requires Accessibility permission.
final class TerminalService {
    static let shared = TerminalService()

    private enum Bundle {
        static let appleTerminal = "com.apple.Terminal"
        static let iterm = "com.googlecode.iterm2"
    }

    /// The last app that was frontmost *other than* Shell Drive itself.
    private var lastExternalApp: NSRunningApplication?

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        if let front = NSWorkspace.shared.frontmostApplication, !isSelf(front) {
            lastExternalApp = front
        }
    }

    // MARK: - Clipboard

    @discardableResult
    func copyToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    // MARK: - Paste

    /// Copy `text`, focus the target terminal, then paste with ⌘V.
    func pasteToTerminal(_ text: String) {
        copyToClipboard(text)
        guard ensureAccessibilityPermission() else { return }
        targetApp()?.activate(options: [])
        // Give the OS a moment to bring the target app forward before pasting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.sendKey(.v, command: true)
        }
    }

    // MARK: - Run

    /// Open the user's chosen terminal and execute the command. Terminal & iTerm
    /// use AppleScript; other terminals fall back to activate + paste + Return.
    func runInTerminal(_ command: String) {
        switch TerminalPreference.bundleID {
        case Bundle.appleTerminal: runViaAppleTerminal(command)
        case Bundle.iterm:         runViaITerm(command)
        default:                   runViaPaste(command, bundleID: TerminalPreference.bundleID)
        }
    }

    private func runViaAppleTerminal(_ command: String) {
        runAppleScript("""
        tell application "Terminal"
            activate
            do script "\(escapeForAppleScript(command))"
        end tell
        """)
    }

    private func runViaITerm(_ command: String) {
        runAppleScript("""
        tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow to write text "\(escapeForAppleScript(command))"
        end tell
        """)
    }

    /// For terminals without scripting: copy, bring the app up (launching if
    /// needed), then synthesize ⌘V and Return into the focused session.
    private func runViaPaste(_ command: String, bundleID: String) {
        copyToClipboard(command)
        guard ensureAccessibilityPermission() else { return }
        activateOrLaunch(bundleID: bundleID) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.sendKey(.v, command: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self?.sendKey(.return)
                }
            }
        }
    }

    // MARK: - Accessibility

    @discardableResult
    func ensureAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        return trusted
    }

    // MARK: - Target resolution

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              !isSelf(app) else { return }
        lastExternalApp = app
    }

    private func isSelf(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == Foundation.Bundle.main.bundleIdentifier
    }

    /// The best paste target: the user's chosen terminal if running, else the
    /// last-used terminal, else any running terminal, else the last external app.
    private func targetApp() -> NSRunningApplication? {
        let running = NSWorkspace.shared.runningApplications
        if let preferred = running.first(where: { $0.bundleIdentifier == TerminalPreference.bundleID }) {
            return preferred
        }
        if let last = lastExternalApp, let id = last.bundleIdentifier,
           TerminalCatalog.bundleIDs.contains(id) {
            return last
        }
        if let anyTerminal = running.first(where: {
            ($0.bundleIdentifier).map(TerminalCatalog.bundleIDs.contains) ?? false
        }) {
            return anyTerminal
        }
        return lastExternalApp
    }

    private func activateOrLaunch(bundleID: String, then: @escaping () -> Void) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            app.activate(options: [])
            then()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { then() }
            }
        } else {
            then()
        }
    }

    // MARK: - Low-level helpers

    private enum Key: CGKeyCode { case v = 9, `return` = 36 }

    private func sendKey(_ key: Key, command: Bool = false) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false)
        if command { down?.flags = .maskCommand; up?.flags = .maskCommand }
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func runAppleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }
}
