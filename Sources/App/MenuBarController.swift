import AppKit
import SwiftUI

/// Owns the menu-bar status item and the floating panel that hosts the SwiftUI
/// UI. We use an NSPanel instead of SwiftUI's `MenuBarExtra` because the latter's
/// `.window` popover auto-dismisses on any focus loss (sheets, menus, even the
/// Accessibility prompt collapse it). The panel stays put and we dismiss it
/// ourselves on an outside click.
final class MenuBarController {
    private let store = DriveStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: NSPanel
    private var outsideClickMonitor: Any?

    private let panelSize = NSSize(width: 344, height: 524)
    private let gapBelowMenuBar: CGFloat = 8

    init() {
        panel = MenuBarController.makePanel(size: panelSize, store: store)
        _ = TerminalService.shared          // start tracking the frontmost terminal early
        installMainMenu()                   // enables ⌘C/⌘V/⌘X/⌘A/⌘Z in text fields
        configureStatusItem()
    }

    // MARK: - Status item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarController.menuBarIcon()
        button.action = #selector(handleClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// The app icon (coral terminal), sized for the menu bar and shown in color.
    private static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: AppInfo.iconResource, withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false         // keep the coral color, don't tint to mono
            return icon
        }
        return NSImage(systemSymbolName: "terminal", accessibilityDescription: AppInfo.name)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel(below: sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit \(AppInfo.name)",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil               // restore left-click behavior
    }

    // MARK: - Panel

    private static func makePanel(size: NSSize, store: DriveStore) -> NSPanel {
        let hosting = NSHostingController(rootView: RootView().environmentObject(store))
        let panel = NSPanel(contentViewController: hosting)
        panel.setContentSize(size)
        panel.styleMask = [.titled, .closable, .fullSizeContentView]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        // Anchored under the menu-bar icon; window-background dragging is off so
        // it doesn't hijack the in-app row drag-and-drop.
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        // Transparent so the SwiftUI vibrancy material renders true behind-window blur.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        hosting.view.wantsLayer = true
        return panel
    }

    private func togglePanel(below button: NSStatusBarButton) {
        if panel.isVisible {
            hidePanel()
        } else {
            position(below: button)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    self?.hidePanel()
                }
        }
    }

    private func hidePanel() {
        panel.orderOut(nil)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    /// Places the panel just below the status item, centered on it, clamped to screen.
    private func position(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let onScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size
        var x = onScreen.midX - size.width / 2
        var y = onScreen.minY - gapBelowMenuBar - size.height

        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        if y < visible.minY + 8 { y = visible.minY + 8 }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Main menu

    /// Accessory apps have no main menu by default, so standard editing shortcuts
    /// don't reach the focused text field. Install a minimal App + Edit menu.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit \(AppInfo.name)",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}
