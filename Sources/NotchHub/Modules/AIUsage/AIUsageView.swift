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
            HStack(spacing: 10) {
                tile("Current 5h window", value: module.stats.blockWork, messages: module.stats.blockMessages,
                     footnote: resetText)
                tile("Today", value: module.stats.todayWork, messages: module.stats.todayMessages, footnote: nil)
                tile("Last 7 days", value: module.stats.weekWork, messages: module.stats.weekMessages, footnote: nil)
            }

            if module.budget > 0 {
                let fraction = min(1, Double(module.stats.blockWork) / Double(module.budget))
                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(value: fraction).tint(fraction > 0.85 ? .red : (fraction > 0.6 ? .orange : .green))
                    Text("\(Int(fraction * 100))% of your \(AIUsageModule.abbreviate(module.budget)) token budget")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Claude Code logs · input + output tokens, cache excluded")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                iconButton("arrow.clockwise") { module.refresh() }
                iconButton("gearshape") { showSettings = true }
            }
        }
        .padding(.horizontal, 6)
    }

    private var resetText: String? {
        guard let end = module.stats.blockEnd else { return "No active window" }
        let minutes = max(0, Int(end.timeIntervalSinceNow / 60))
        return "Resets in \(minutes / 60)h \(minutes % 60)m"
    }

    private func tile(_ title: String, value: Int, messages: Int, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(AIUsageModule.abbreviate(value))
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("\(messages) responses").font(.system(size: 10)).foregroundStyle(.secondary)
            Text(footnote ?? " ").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(.secondary)
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
                Text("Token budget per 5h window")
                    .font(.system(size: 12))
                TextField("0", value: $module.budget, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                Text("0 = no limit bar").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text("Anthropic does not publish your remaining quota locally, so set a budget you want to stay under.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Divider()
            Text("Live API integration · coming later")
                .font(.system(size: 11, weight: .medium))
            Text("A future version can read real limits through an official API. No keys are stored or bundled in this build.")
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
