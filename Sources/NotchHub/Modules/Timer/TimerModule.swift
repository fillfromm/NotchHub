import Foundation
import SwiftUI

/// Countdown, stopwatch and Pomodoro in one module.
///
/// Time is derived from wall-clock dates (not tick counting), so it stays
/// accurate even if the run loop is delayed.
final class TimerModule: NotchModule, ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case countdown = "Timer"
        case stopwatch = "Stopwatch"
        case pomodoro = "Pomodoro"
        var id: String { rawValue }
    }

    enum PomodoroPhase {
        case work, shortBreak, longBreak

        var label: String {
            switch self {
            case .work: return "Focus"
            case .shortBreak: return "Short break"
            case .longBreak: return "Long break"
            }
        }
        var duration: TimeInterval {
            switch self {
            case .work: return 25 * 60
            case .shortBreak: return 5 * 60
            case .longBreak: return 15 * 60
            }
        }
    }

    let id = "timer"
    let title = "Timer"
    let icon = "timer"

    @Published var mode: Mode = .countdown {
        didSet { if mode != oldValue { reset() } }
    }
    /// Seconds shown on screen (remaining for countdown/pomodoro, elapsed for stopwatch).
    @Published private(set) var displayTime: TimeInterval = 5 * 60
    @Published private(set) var isRunning = false
    /// Configured countdown length in minutes.
    @Published var countdownMinutes = 5 {
        didSet { if mode == .countdown, !isRunning { reset() } }
    }
    @Published private(set) var phase: PomodoroPhase = .work
    @Published private(set) var completedPomodoros = 0

    private var timer: Timer?
    private var endDate: Date?          // countdown / pomodoro: when it hits zero
    private var startDate: Date?        // stopwatch: when the current run started
    private var accumulated: TimeInterval = 0 // stopwatch: time from earlier runs

    init() {
        displayTime = TimeInterval(countdownMinutes * 60)
    }

    deinit { timer?.invalidate() }

    var compactInfo: CompactInfo? {
        // Show only while running, or while a paused countdown is partially elapsed.
        guard isRunning else { return nil }
        return CompactInfo(icon: mode == .stopwatch ? "stopwatch" : "timer", text: Self.format(displayTime), priority: 20)
    }

    func makeView() -> AnyView { AnyView(TimerView(module: self)) }

    // MARK: Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        Notifier.requestAuthorization()
        switch mode {
        case .stopwatch:
            startDate = Date()
        case .countdown, .pomodoro:
            if displayTime <= 0 { displayTime = fullDuration }
            endDate = Date().addingTimeInterval(displayTime)
        }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func pause() {
        guard isRunning else { return }
        tick()
        if mode == .stopwatch { accumulated = displayTime; startDate = nil }
        stopTimer()
    }

    func reset() {
        stopTimer()
        accumulated = 0
        startDate = nil
        endDate = nil
        if mode == .pomodoro { phase = .work }
        displayTime = mode == .stopwatch ? 0 : fullDuration
    }

    /// Jumps to the next Pomodoro phase without waiting for the timer.
    func skipPhase() {
        guard mode == .pomodoro else { return }
        advancePomodoro(countCompleted: false)
    }

    /// Full length of the current countdown / pomodoro phase.
    private var fullDuration: TimeInterval {
        mode == .pomodoro ? phase.duration : TimeInterval(countdownMinutes * 60)
    }

    // MARK: Ticking

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func tick() {
        switch mode {
        case .stopwatch:
            displayTime = accumulated + (startDate.map { Date().timeIntervalSince($0) } ?? 0)
        case .countdown, .pomodoro:
            guard let endDate else { return }
            displayTime = max(0, endDate.timeIntervalSinceNow)
            if displayTime <= 0 { finish() }
        }
    }

    private func finish() {
        stopTimer()
        switch mode {
        case .countdown:
            Notifier.notify(title: "Timer finished", body: "\(countdownMinutes) minute timer is done.")
            displayTime = fullDuration
        case .pomodoro:
            Notifier.notify(title: "\(phase.label) finished",
                            body: phase == .work ? "Time for a break." : "Back to focus.")
            advancePomodoro(countCompleted: true)
            start() // phases chain automatically
        case .stopwatch:
            break
        }
    }

    /// work → short break (long break after every 4th) → work …
    private func advancePomodoro(countCompleted: Bool) {
        let wasRunning = isRunning
        stopTimer()
        if phase == .work {
            if countCompleted { completedPomodoros += 1 }
            phase = (completedPomodoros > 0 && completedPomodoros % 4 == 0) ? .longBreak : .shortBreak
        } else {
            phase = .work
        }
        displayTime = phase.duration
        if wasRunning { start() }
    }

    // MARK: Formatting

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
