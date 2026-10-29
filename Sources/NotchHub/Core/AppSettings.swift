import Foundation
import ServiceManagement

/// How the notch opens.
enum ExpandMode: String, CaseIterable {
    case hover
    case click

    var label: String {
        switch self {
        case .hover: return "Expand on hover"
        case .click: return "Expand on click"
        }
    }
}

/// Where the module icons sit in the expanded notch.
enum TabBarPosition: String, CaseIterable {
    case top
    case side

    var label: String { self == .top ? "Top" : "Side" }
}

/// User preferences, persisted in `UserDefaults`.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let expandMode = "expandMode"
        static let disabledModules = "disabledModules"
        static let iconSize = "iconSize"
        static let hoverZoom = "hoverZoom"
        static let tabBarPosition = "tabBarPosition"
        static let importScreenshots = "importScreenshots"
        static let trashScreenshots = "trashScreenshots"
    }

    static let iconSizes: [(label: String, value: Double)] = [("Small", 14), ("Medium", 18), ("Large", 22)]
    static let hoverZooms: [(label: String, value: Double)] = [("Off", 1.0), ("Medium", 1.35), ("Large", 1.7)]

    /// Size of the tab icons in points (menu offers presets).
    @Published var iconSize: Double {
        didSet { defaults.set(iconSize, forKey: Key.iconSize) }
    }

    /// Scale applied to the icon under the mouse (1.0 = no zoom).
    @Published var hoverZoom: Double {
        didSet { defaults.set(hoverZoom, forKey: Key.hoverZoom) }
    }

    /// Icons around the notch (top) or in a column on the left (side).
    @Published var tabBarPosition: TabBarPosition {
        didSet { defaults.set(tabBarPosition.rawValue, forKey: Key.tabBarPosition) }
    }

    /// Pick up screenshot files that macOS saves to disk and show them in the clipboard tab.
    @Published var importScreenshots: Bool {
        didSet { defaults.set(importScreenshots, forKey: Key.importScreenshots) }
    }

    /// Move the original file to the Trash after importing it, so the Desktop stays clean.
    @Published var trashScreenshots: Bool {
        didSet { defaults.set(trashScreenshots, forKey: Key.trashScreenshots) }
    }

    @Published var expandMode: ExpandMode {
        didSet { defaults.set(expandMode.rawValue, forKey: Key.expandMode) }
    }

    /// Stored as a "disabled" set so newly added modules are enabled by default.
    @Published private(set) var disabledModules: Set<String>

    private init() {
        expandMode = ExpandMode(rawValue: defaults.string(forKey: Key.expandMode) ?? "") ?? .hover
        tabBarPosition = TabBarPosition(rawValue: defaults.string(forKey: Key.tabBarPosition) ?? "") ?? .top
        importScreenshots = defaults.object(forKey: Key.importScreenshots) as? Bool ?? true
        trashScreenshots = defaults.object(forKey: Key.trashScreenshots) as? Bool ?? true
        iconSize = defaults.object(forKey: Key.iconSize) as? Double ?? 18
        hoverZoom = defaults.object(forKey: Key.hoverZoom) as? Double ?? 1.35
        disabledModules = Set(defaults.stringArray(forKey: Key.disabledModules) ?? [])
    }

    func isEnabled(_ moduleID: String) -> Bool {
        !disabledModules.contains(moduleID)
    }

    func setEnabled(_ moduleID: String, _ enabled: Bool) {
        if enabled { disabledModules.remove(moduleID) } else { disabledModules.insert(moduleID) }
        defaults.set(Array(disabledModules), forKey: Key.disabledModules)
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers / unregisters the app as a login item. Only works from the `.app` bundle.
    @discardableResult
    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            objectWillChange.send()
            return true
        } catch {
            NSLog("NotchHub: launch at login failed: \(error.localizedDescription)")
            return false
        }
    }
}
