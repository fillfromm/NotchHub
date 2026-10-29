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

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(header("Modules"))
        for module in registry.all {
            let item = NSMenuItem(title: module.title, action: #selector(toggleModule(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = module.id
            item.state = settings.isEnabled(module.id) ? .on : .off
            item.image = NSImage(systemSymbolName: module.icon, accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(header("Open notch"))
        for mode in ExpandMode.allCases {
            let item = NSMenuItem(title: mode.label, action: #selector(setMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = settings.expandMode == mode ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = settings.launchAtLogin ? .on : .off
        menu.addItem(login)

        let automation = NSMenuItem(title: "Privacy settings (Automation)…", action: #selector(openAutomationSettings), keyEquivalent: "")
        automation.target = self
        menu.addItem(automation)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchHub", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func toggleModule(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.setEnabled(id, !settings.isEnabled(id))
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = ExpandMode(rawValue: raw) else { return }
        settings.expandMode = mode
    }

    @objc private func toggleLogin() {
        settings.setLaunchAtLogin(!settings.launchAtLogin)
    }

    @objc private func openAutomationSettings() {
        PermissionHelper.openAutomationSettings()
    }
}
