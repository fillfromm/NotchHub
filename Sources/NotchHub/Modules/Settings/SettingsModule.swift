import SwiftUI

/// All app settings, inside the notch: modules on/off, how the notch opens,
/// tab bar position and size, launch at login, quit.
final class SettingsModule: NotchModule, ObservableObject {
    let id = "settings"
    let title = "Settings"
    let icon = "gearshape"
    var alwaysEnabled: Bool { true }

    /// Set by the registry; returns every module so they can be toggled.
    var allModules: () -> [NotchModule] = { [] }

    func makeView() -> AnyView { AnyView(SettingsView(module: self)) }
}
