import AppKit
import SwiftUI

/// Countdown timer, stopwatch and alarm clock in one module.
///
/// The three tools are independent: switching tabs never stops one that is running.
/// Times are derived from wall-clock dates (not tick counting), so they stay accurate
/// even if the run loop is delayed.
final class TimerModule: NotchModule, ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case countdown = "Timer"
        case stopwatch = "Stopwatch"
        case alarm = "Alarm"
        var id: String { rawValue }
    }

    let id = "timer"
    let title = "Timer & Alarm"
    let icon = "timer"

    private static let alarmHourKey = "alarm.hour"
    private static let alarmMinuteKey = "alarm.minute"
    private static let alarmArmedKey = "alarm.armed"

    @Published var mode: Mode = .countdown

    // MARK: Countdown state

    @Published var countdownHours = 0 { didSet { syncIdleCountdown() } }
    @Published var countdownMinutes = 5 { didSet { syncIdleCountdown() } }
    @Published var countdownSeconds = 0 { didSet { syncIdleCountdown() } }
    @Published private(set) var countdownRemaining: TimeInterval = 5 * 60
    @Published private(set) var countdownRunning = false
    private var countdownEnd: Date?

    // MARK: Stopwatch state

    @Published private(set) var stopwatchElapsed: TimeInterval = 0
    @Published private(set) var stopwatchRunning = false
    private var stopwatchStart: Date?
    private var stopwatchAccumulated: TimeInterval = 0

    // MARK: Alarm state

    @Published var alarmHour: Int { didSet { alarmTimeChanged() } }
    @Published var alarmMinute: Int { didSet { alarmTimeChanged() } }
    @Published private(set) var alarmArmed = false
    @Published private(set) var isRinging = false
    private var alarmTarget: Date?
    private var alarmTimer: Timer?
    private var ringTimer: Timer?
    private var ringCount = 0

    private var ticker: Timer?

    init() {
        let defaults = UserDefaults.standard
        let savedHour = defaults.object(forKey: Self.alarmHourKey) as? Int
        alarmHour = savedHour ?? 7
        alarmMinute = defaults.object(forKey: Self.alarmMinuteKey) as? Int ?? 0
        if defaults.bool(forKey: Self.alarmArmedKey) { armAlarm() }
    }

    deinit { ticker?.invalidate(); alarmTimer?.invalidate(); ringTimer?.invalidate() }

    var compactInfo: CompactInfo? {
        if isRinging { return CompactInfo(icon: "alarm.fill", text: "Wake up!", priority: 40) }
        if countdownRunning { return CompactInfo(icon: "timer", text: Self.format(countdownRemaining), priority: 20) }
        if stopwatchRunning { return CompactInfo(icon: "stopwatch", text: Self.format(stopwatchElapsed), priority: 19) }
        if alarmArmed, let target = alarmTarget, target.timeIntervalSinceNow <= 3600 {
            return CompactInfo(icon: "alarm", text: "in \(max(1, Int((target.timeIntervalSinceNow / 60).rounded(.up))))m", priority: 15)
        }
        return nil
    }

    func makeView() -> AnyView { AnyView(TimerView(module: self)) }

    // MARK: Countdown

    var countdownTotal: TimeInterval {
        TimeInterval(countdownHours * 3600 + countdownMinutes * 60 + countdownSeconds)
    }

    /// True while the wheels (not the running digits) should be shown.
    var countdownIsIdle: Bool {
        !countdownRunning && countdownRemaining == countdownTotal
    }

    /// While idle, the displayed time follows the wheels.
    private func syncIdleCountdown() {
        if !countdownRunning { countdownRemaining = countdownTotal }
    }

    func toggleCountdown() {
        if countdownRunning { pauseCountdown() } else { startCountdown() }
    }

    func startCountdown() {
        guard !countdownRunning, countdownRemaining > 0 else { return }
        Notifier.requestAuthorization()
        countdownEnd = Date().addingTimeInterval(countdownRemaining)
        countdownRunning = true
        startTicker()
    }

    func pauseCountdown() {
        tick()
        countdownRunning = false
        countdownEnd = nil
    }

    func resetCountdown() {
        countdownRunning = false
        countdownEnd = nil
        countdownRemaining = countdownTotal
    }

    private func finishCountdown() {
        countdownRunning = false
        countdownEnd = nil
        countdownRemaining = countdownTotal
        Notifier.notify(title: "Timer finished", body: "\(Self.format(countdownTotal)) timer is done.")
    }

    // MARK: Stopwatch

    func toggleStopwatch() {
        if stopwatchRunning {
            tick()
            stopwatchAccumulated = stopwatchElapsed
            stopwatchStart = nil
            stopwatchRunning = false
        } else {
            stopwatchStart = Date()
            stopwatchRunning = true
            startTicker()
        }
    }

    func resetStopwatch() {
        stopwatchRunning = false
        stopwatchStart = nil
        stopwatchAccumulated = 0
        stopwatchElapsed = 0
    }

    // MARK: Ticking (countdown + stopwatch)

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        if countdownRunning, let end = countdownEnd {
            countdownRemaining = max(0, end.timeIntervalSince(now))
            if countdownRemaining <= 0 { finishCountdown() }
        }
        if stopwatchRunning, let start = stopwatchStart {
            stopwatchElapsed = stopwatchAccumulated + now.timeIntervalSince(start)
        }
        if !countdownRunning && !stopwatchRunning {
            ticker?.invalidate()
            ticker = nil
        }
    }

    // MARK: Alarm

    func toggleAlarm() {
        if alarmArmed { disarmAlarm() } else { armAlarm() }
    }

    private func armAlarm() {
        Notifier.requestAuthorization()
        alarmTarget = Self.nextOccurrence(hour: alarmHour, minute: alarmMinute)
        alarmArmed = true
        UserDefaults.standard.set(true, forKey: Self.alarmArmedKey)
        alarmTimer?.invalidate()
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.alarmTick() }
        }
    }

    private func disarmAlarm() {
        alarmArmed = false
        alarmTarget = nil
        alarmTimer?.invalidate()
        alarmTimer = nil
        UserDefaults.standard.set(false, forKey: Self.alarmArmedKey)
    }

    /// Changing the time while the alarm is on re-arms it for the new time.
    private func alarmTimeChanged() {
        UserDefaults.standard.set(alarmHour, forKey: Self.alarmHourKey)
        UserDefaults.standard.set(alarmMinute, forKey: Self.alarmMinuteKey)
        if alarmArmed { alarmTarget = Self.nextOccurrence(hour: alarmHour, minute: alarmMinute) }
    }

    private func alarmTick() {
        guard let target = alarmTarget else { return }
        if Date() >= target { fireAlarm() } else { objectWillChange.send() } // keeps "in 12m" fresh
    }

    private func fireAlarm() {
        disarmAlarm() // one-shot, like a phone alarm without repeat
        isRinging = true
        ringCount = 0
        Notifier.notify(title: "Alarm", body: String(format: "It's %02d:%02d.", alarmHour, alarmMinute))
        ringTimer?.invalidate()
        ringTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.ringCount += 1
                NSSound(named: "Glass")?.play()
                if self.ringCount >= 20 { self.stopRinging() } // stop by itself after ~30s
            }
        }
    }

    func stopRinging() {
        isRinging = false
        ringTimer?.invalidate()
        ringTimer = nil
    }

    /// Next time the clock shows `hour:minute` (today if still ahead, otherwise tomorrow).
    static func nextOccurrence(hour: Int, minute: Int, after date: Date = Date()) -> Date {
        Calendar.current.nextDate(after: date, matching: DateComponents(hour: hour, minute: minute, second: 0),
                                  matchingPolicy: .nextTime) ?? date
    }

    /// "7 h 25 min" until the next occurrence of `hour:minute`.
    static func timeUntil(hour: Int, minute: Int, now: Date = Date()) -> String {
        let seconds = nextOccurrence(hour: hour, minute: minute, after: now).timeIntervalSince(now)
        let total = max(1, Int((seconds / 60).rounded(.up)))
        let h = total / 60, m = total % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    // MARK: Formatting

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
