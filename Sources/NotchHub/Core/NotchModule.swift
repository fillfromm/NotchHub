import Combine
import SwiftUI

/// Small piece of live info a module can show while the notch is collapsed
/// (e.g. the current track or the remaining timer time).
struct CompactInfo: Equatable {
    /// SF Symbol name shown on the left of the notch.
    var icon: String
    /// Short text shown on the right of the notch.
    var text: String
    /// When several modules have compact info, the highest priority wins.
    var priority: Int = 0
}

/// A tool that lives inside the expanded notch.
///
/// To add a module: create a class conforming to `NotchModule` (usually also an
/// `ObservableObject`), then append an instance to `ModuleRegistry.makeDefaultModules()`.
/// Everything in the app runs on the main thread; modules do their background work
/// on private queues and publish results back on main.
protocol NotchModule: AnyObject {
    /// Stable identifier, used to persist the enabled/disabled state.
    var id: String { get }
    /// Human readable name (menu bar, tooltips).
    var title: String { get }
    /// SF Symbol shown in the icon bar.
    var icon: String { get }
    /// Optional info for the collapsed notch.
    var compactInfo: CompactInfo? { get }
    /// Modules that can't be disabled in settings. Defaults to false.
    var alwaysEnabled: Bool { get }
    /// Fires whenever the module's state changes, so the notch can refresh.
    var statePublisher: AnyPublisher<Void, Never> { get }
    /// The full-size view shown in the expanded notch.
    func makeView() -> AnyView
}

extension NotchModule {
    var compactInfo: CompactInfo? { nil }
    /// True for modules that can't be switched off (the Settings tab).
    var alwaysEnabled: Bool { false }
}

extension NotchModule where Self: ObservableObject {
    /// Default: forward the `ObservableObject` change notifications.
    var statePublisher: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }
}
