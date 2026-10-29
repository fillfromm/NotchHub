import SwiftUI

/// Shows how much of your Claude Code usage is left, by reading its local logs.
///
/// Anthropic doesn't expose the real plan limit locally, so "% left" is measured
/// against a limit you can set yourself, or (by default) against your busiest
/// 5-hour window of the last week, which is marked as an estimate in the UI.
/// A placeholder is left for a future API integration; no keys are stored.
final class AIUsageModule: NotchModule, ObservableObject {
    let id = "ai"
    let title = "AI usage"
    let icon = "sparkles"

    private static let budgetKey = "ai.budget5h"

    @Published private(set) var stats = UsageStats()
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var hasData = UsageScanner.hasData
    /// Optional token limit for one 5-hour window (0 = estimate automatically).
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

    // MARK: Limit and percentage

    /// The limit the percentage is measured against.
    var limit: Int { budget > 0 ? budget : stats.blockMax }
    var isEstimated: Bool { budget <= 0 }

    /// 0...1 of the current window still available; nil when there is nothing to compare to.
    var fractionLeft: Double? {
        guard limit > 0 else { return nil }
        return max(0, 1 - Double(stats.blockWork) / Double(limit))
    }

    var percentLeft: Int? { fractionLeft.map { Int(($0 * 100).rounded()) } }

    /// Warn in the collapsed notch when the window is nearly used up.
    var compactInfo: CompactInfo? {
        guard stats.blockEnd != nil, let percent = percentLeft, percent <= 20 else { return nil }
        return CompactInfo(icon: "sparkles", text: "\(percent)% left", priority: 12)
    }

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
