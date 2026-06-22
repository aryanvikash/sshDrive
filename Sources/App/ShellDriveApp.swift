import AppKit

// Shell Drive is a menu-bar accessory (no Dock icon). It uses AppKit's
// NSApplication directly rather than the SwiftUI App lifecycle, because the
// UI is hosted in a manually-managed NSPanel (see MenuBarController).
@main
enum ShellDriveApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // menu-bar agent, no Dock icon
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = MenuBarController()
    }
}
