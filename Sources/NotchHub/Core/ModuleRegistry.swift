import Combine
import SwiftUI

/// Owns all modules, knows which are enabled and which tab is selected.
final class ModuleRegistry: ObservableObject {
    let all: [NotchModule]
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    /// The last used tab is remembered, so the notch reopens on it (also after a restart).
    @Published var selectedID: String {
        didSet { UserDefaults.standard.set(selectedID, forKey: "selectedTab") }
    }

    init(settings: AppSettings = .shared, modules: [NotchModule]? = nil) {
        self.settings = settings
        self.all = modules ?? ModuleRegistry.makeDefaultModules()
        self.selectedID = UserDefaults.standard.string(forKey: "selectedTab") ?? all.first?.id ?? ""

        // The settings tab lists every module so it can switch them on and off.
        (all.first { $0 is SettingsModule } as? SettingsModule)?.allModules = { [unowned self] in self.all }

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
            VolumeModule(),
            CalendarModule(),
            ProfileModule(),
            TranslatorModule(),
            WindowsModule(),
            PicturesModule(),
            SettingsModule(),   // keep last: it is the "gear" tab
        ]
    }

    var enabled: [NotchModule] {
        all.filter { $0.alwaysEnabled || settings.isEnabled($0.id) }
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
