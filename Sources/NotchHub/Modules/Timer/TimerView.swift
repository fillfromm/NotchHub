import SwiftUI

struct TimerView: View {
    @ObservedObject var module: TimerModule

    var body: some View {
        VStack(spacing: 10) {
            Picker("", selection: $module.mode) {
                ForEach(TimerModule.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)

            HStack(spacing: 28) {
                presetColumn
                    .frame(width: 130, alignment: .trailing)

                VStack(spacing: 2) {
                    Text(TimerModule.format(module.displayTime))
                        .font(.system(size: 44, weight: .light, design: .rounded).monospacedDigit())
                    if module.mode == .pomodoro {
                        Text("\(module.phase.label) · \(module.completedPomodoros) done")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 160)

                HStack(spacing: 10) {
                    roundButton(module.isRunning ? "pause.fill" : "play.fill", prominent: true) { module.toggle() }
                    roundButton("arrow.counterclockwise") { module.reset() }
                    if module.mode == .pomodoro {
                        roundButton("forward.end.fill") { module.skipPhase() }
                    }
                }
                .frame(width: 130, alignment: .leading)
            }
        }
    }

    /// Quick presets (countdown) or a short hint for the other modes.
    @ViewBuilder
    private var presetColumn: some View {
        switch module.mode {
        case .countdown:
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach([1, 5, 10, 25], id: \.self) { minutes in
                        Button("\(minutes)") { module.countdownMinutes = minutes }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 26, height: 20)
                            .background(Capsule().fill(Color.white.opacity(module.countdownMinutes == minutes ? 0.25 : 0.1)))
                    }
                }
                Stepper("\(module.countdownMinutes) min", value: $module.countdownMinutes, in: 1...180)
                    .font(.system(size: 11))
                    .disabled(module.isRunning)
            }
        case .stopwatch:
            Text("Counts up").font(.system(size: 11)).foregroundStyle(.secondary)
        case .pomodoro:
            Text("25 / 5 · long break every 4")
                .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private func roundButton(_ symbol: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 16 : 13, weight: .semibold))
                .frame(width: prominent ? 40 : 32, height: prominent ? 40 : 32)
                .background(Circle().fill(Color.white.opacity(prominent ? 0.25 : 0.12)))
        }
        .buttonStyle(.plain)
    }
}
