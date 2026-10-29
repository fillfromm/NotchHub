import Combine
import SwiftUI

/// Owns all modules, knows which are enabled and which tab is selected.
final class ModuleRegistry: ObservableObject {
    let all: [NotchModule]
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    @Published var selectedID: String

    init(settings: AppSettings = .shared, modules: [NotchModule]? = nil) {
        self.settings = settings
        self.all = modules ?? ModuleRegistry.makeDefaultModules()
        self.selectedID = all.first?.id ?? ""

        // Re-publish module and settings changes so SwiftUI and the controller refresh.
        for module in all {
            module.statePublisher
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
        settings.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// The module list. Add new modules here.
    static func makeDefaultModules() -> [NotchModule] {
        [
            MusicModule(),
            TimerModule(),
            ClipboardModule(),
            AIUsageModule(),
            NotesModule(),
            SystemModule(),
            CalendarModule(),
        ]
    }

    var enabled: [NotchModule] {
        all.filter { settings.isEnabled($0.id) }
    }

    /// Selected module, falling back to the first enabled one.
    var selected: NotchModule? {
        let list = enabled
        return list.first { $0.id == selectedID } ?? list.first
    }

    /// Highest-priority compact info among enabled modules.
    var compactInfo: CompactInfo? {
        enabled.compactMap { $0.compactInfo }.max { $0.priority < $1.priority }
    }

    func select(_ module: NotchModule) {
        selectedID = module.id
    }
}
