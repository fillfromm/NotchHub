import SwiftUI

struct AIUsageView: View {
    @ObservedObject var module: AIUsageModule
    @State private var showSettings = false

    var body: some View {
        if !module.hasData {
            placeholder
        } else if showSettings {
            settings
        } else {
            usage
        }
    }

    // MARK: Usage

    private var usage: some View {
        VStack(spacing: 10) {
            // Main answer: how much is left in the current 5-hour window.
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(module.percentLeft.map { "\($0)% left" } ?? "No data yet")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(resetText).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ProgressView(value: module.fractionLeft ?? 0)
                    .tint(barColor)
                    .scaleEffect(x: 1, y: 1.6)
                Text(detailText)
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                miniStat("Today", value: module.stats.todayWork)
                miniStat("Last 7 days", value: module.stats.weekWork)
                Spacer()
                iconButton("arrow.clockwise") { module.refresh() }
                iconButton("gearshape") { showSettings = true }
            }
        }
        .padding(.horizontal, 6)
    }

    private var barColor: Color {
        guard let left = module.fractionLeft else { return .gray }
        return left < 0.15 ? .red : (left < 0.4 ? .orange : .green)
    }

    private var resetText: String {
        guard let end = module.stats.blockEnd else { return "No active 5h window" }
        let minutes = max(0, Int(end.timeIntervalSinceNow / 60))
        return "Resets in \(minutes / 60)h \(minutes % 60)m"
    }

    private var detailText: String {
        guard module.limit > 0 else { return "Use Claude Code and the percentage will appear here." }
        let used = AIUsageModule.abbreviate(module.stats.blockWork)
        let limit = AIUsageModule.abbreviate(module.limit)
        return module.isEstimated
            ? "\(used) used of ~\(limit) (your busiest window this week, an estimate). Tap ⚙ to set your own limit."
            : "\(used) used of your \(limit) limit per 5-hour window."
    }

    private func miniStat(_ title: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(AIUsageModule.abbreviate(value)).font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(width: 26, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usage settings").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done") { showSettings = false }.controlSize(.small)
            }
            HStack {
                Text("Token limit per 5h window").font(.system(size: 12))
                TextField("0", value: $module.budget, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                Text("0 = estimate automatically").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text("Anthropic does not publish your remaining quota locally. By default the limit is your busiest 5-hour window of the past week; enter a number to measure against your own limit. Counts input + output tokens from Claude Code logs, cache excluded.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Divider()
            Text("Live API integration · coming later").font(.system(size: 11, weight: .medium))
            Text("No keys are stored or bundled in this build.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    // MARK: Empty state

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 24)).foregroundStyle(.secondary)
            Text("No Claude Code data found").font(.system(size: 13, weight: .medium))
            Text("Looked in ~/.claude/projects. Use Claude Code once and usage will appear here.")
                .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Check again") { module.refresh() }.controlSize(.small)
        }
        .padding(.horizontal, 30)
    }
}
