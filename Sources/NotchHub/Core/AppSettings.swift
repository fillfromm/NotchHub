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

/// User preferences, persisted in `UserDefaults`.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let expandMode = "expandMode"
        static let disabledModules = "disabledModules"
    }

    @Published var expandMode: ExpandMode {
        didSet { defaults.set(expandMode.rawValue, forKey: Key.expandMode) }
    }

    /// Stored as a "disabled" set so newly added modules are enabled by default.
    @Published private(set) var disabledModules: Set<String>

    private init() {
        expandMode = ExpandMode(rawValue: defaults.string(forKey: Key.expandMode) ?? "") ?? .hover
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
