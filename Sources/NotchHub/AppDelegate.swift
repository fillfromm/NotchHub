import AppKit

/// Creates the notch and the menu bar item (module toggles, expand mode, login item, quit).
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private var registry: ModuleRegistry!
    private var notch: NotchController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        registry = ModuleRegistry(settings: settings)
        notch = NotchController(registry: registry, settings: settings)
        notch.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                           accessibilityDescription: "NotchHub")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: Menu (rebuilt each time it opens so check marks are current)

    /// Everything is configured inside the notch (Settings tab); the menu only offers a way out.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let open = NSMenuItem(title: "Open settings", action: #selector(openSettings), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchHub", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func openSettings() {
        registry.selectedID = "settings"
        notch.expand()
    }
}
