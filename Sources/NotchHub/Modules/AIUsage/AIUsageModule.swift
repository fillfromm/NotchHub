import SwiftUI

/// Shows Claude Code usage by reading its local logs.
///
/// Anthropic doesn't expose plan limits locally, so the limit bar is driven by an
/// optional token budget you set yourself. A placeholder is left for a future
/// API integration; no keys are stored or hardcoded.
final class AIUsageModule: NotchModule, ObservableObject {
    let id = "ai"
    let title = "AI usage"
    let icon = "sparkles"

    private static let budgetKey = "ai.budget5h"

    @Published private(set) var stats = UsageStats()
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var hasData = UsageScanner.hasData
    /// Optional token budget for one 5-hour window (0 = not set).
    @Published var budget: Int {
        didSet { UserDefaults.standard.set(budget, forKey: Self.budgetKey) }
    }

    private var timer: Timer?

    init() {
        budget = UserDefaults.standard.integer(forKey: Self.budgetKey)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    func makeView() -> AnyView { AnyView(AIUsageView(module: self)) }

    /// Re-reads the logs on a background queue.
    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let entries = UsageScanner.scan(since: Date().addingTimeInterval(-8 * 86400))
            let stats = UsageScanner.stats(from: entries)
            DispatchQueue.main.async {
                guard let self else { return }
                self.stats = stats
                self.hasData = UsageScanner.hasData
                self.lastUpdated = Date()
                self.isLoading = false
            }
        }
    }

    // MARK: Formatting

    static func abbreviate(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...: return String(format: "%.1fK", Double(n) / 1_000)
        default: return "\(n)"
        }
    }
}
