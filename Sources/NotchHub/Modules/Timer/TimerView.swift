import SwiftUI

struct TimerView: View {
    @ObservedObject var module: TimerModule

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $module.mode) {
                ForEach(TimerModule.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)

            Group {
                switch module.mode {
                case .countdown: countdown
                case .stopwatch: stopwatch
                case .alarm: alarm
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Timer

    @ViewBuilder
    private var countdown: some View {
        if module.countdownIsIdle {
            // Wheels, like the Clock app on iPhone.
            HStack(spacing: 34) {
                HStack(spacing: 6) {
                    wheel($module.countdownHours, 0...23, "h")
                    wheel($module.countdownMinutes, 0...59, "min")
                    wheel($module.countdownSeconds, 0...59, "s")
                }
                roundButton("play.fill", prominent: true) { module.startCountdown() }
                    .disabled(module.countdownTotal == 0)
                    .opacity(module.countdownTotal == 0 ? 0.4 : 1)
            }
        } else {
            HStack(spacing: 34) {
                bigTime(TimerModule.format(module.countdownRemaining))
                HStack(spacing: 10) {
                    roundButton(module.countdownRunning ? "pause.fill" : "play.fill", prominent: true) { module.toggleCountdown() }
                    roundButton("xmark") { module.resetCountdown() }
                }
            }
        }
    }

    // MARK: Stopwatch

    private var stopwatch: some View {
        HStack(spacing: 34) {
            bigTime(TimerModule.format(module.stopwatchElapsed))
            HStack(spacing: 10) {
                roundButton(module.stopwatchRunning ? "pause.fill" : "play.fill", prominent: true) { module.toggleStopwatch() }
                roundButton("arrow.counterclockwise") { module.resetStopwatch() }
            }
        }
    }

    // MARK: Alarm

    private var alarm: some View {
        HStack(spacing: 34) {
            HStack(spacing: 4) {
                wheel($module.alarmHour, 0...23, nil)
                Text(":").font(.system(size: 22, weight: .semibold, design: .rounded))
                wheel($module.alarmMinute, 0...59, nil)
            }

            VStack(spacing: 10) {
                if module.isRinging {
                    Text("Alarm!").font(.system(size: 22, weight: .semibold))
                    Button("Stop") { module.stopRinging() }
                        .buttonStyle(.borderedProminent).tint(.orange)
                } else {
                    // Updates every second so it stays correct while you spin the wheels.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 2) {
                            Text(module.alarmArmed ? "Rings in" : "Would ring in")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(TimerModule.timeUntil(hour: module.alarmHour, minute: module.alarmMinute, now: context.date))
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                        }
                    }
                    Button(module.alarmArmed ? "Turn off" : "Set alarm") { module.toggleAlarm() }
                        .buttonStyle(.borderedProminent)
                        .tint(module.alarmArmed ? .gray : .orange)
                }
            }
            .frame(width: 170)
        }
    }

    // MARK: Pieces

    private func wheel(_ value: Binding<Int>, _ range: ClosedRange<Int>, _ unit: String?) -> some View {
        HStack(spacing: 2) {
            WheelPicker(value: value, range: range)
            if let unit {
                Text(unit).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 22, alignment: .leading)
            }
        }
    }

    private func bigTime(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 52, weight: .light, design: .rounded).monospacedDigit())
            .frame(minWidth: 190)
    }

    private func roundButton(_ symbol: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 18 : 14, weight: .semibold))
                .frame(width: prominent ? 46 : 36, height: prominent ? 46 : 36)
                .background(Circle().fill(Color.white.opacity(prominent ? 0.25 : 0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
