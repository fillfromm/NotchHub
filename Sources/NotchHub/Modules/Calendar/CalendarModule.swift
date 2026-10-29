import AppKit
import EventKit
import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var color: Color

    static func == (a: CalendarEvent, b: CalendarEvent) -> Bool {
        a.id == b.id && a.start == b.start && a.title == b.title
    }
}

/// A reminder you set yourself. Stored locally; a notification fires at `date`.
struct Reminder: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
    var done = false
}

/// Month calendar with your system events (EventKit, read-only) and your own reminders.
final class CalendarModule: NotchModule, ObservableObject {
    enum Access { case notDetermined, granted, denied }

    let id = "calendar"
    let title = "Calendar"
    let icon = "calendar"

    private static let remindersFile = "reminders.json"

    @Published private(set) var access: Access = .notDetermined
    /// First day of the month being shown.
    @Published private(set) var displayedMonth: Date
    @Published var selectedDay: Date
    /// Events of the displayed month, grouped by day.
    @Published private(set) var eventsByDay: [Date: [CalendarEvent]] = [:]
    @Published private(set) var reminders: [Reminder]

    private let store = EKEventStore()
    private let calendar = Calendar.current
    private var nextEvent: CalendarEvent?
    private var timer: Timer?

    init() {
        let today = Calendar.current.startOfDay(for: Date())
        selectedDay = today
        displayedMonth = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
        reminders = LocalStore.load([Reminder].self, from: Self.remindersFile) ?? []
        updateAccess()
        if access == .granted { reload() }

        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.reload()
        }
        // Keeps "in 12 min" labels and the compact info fresh.
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.access == .granted { self.reload() } else { self.objectWillChange.send() }
            }
        }
    }

    deinit { timer?.invalidate() }

    /// Collapsed notch: the next event or reminder if it starts within 15 minutes.
    var compactInfo: CompactInfo? {
        let now = Date()
        var soonest: Date?
        if access == .granted, let event = nextEvent, event.start > now { soonest = event.start }
        for reminder in reminders where !reminder.done && reminder.date > now {
            if soonest == nil || reminder.date < soonest! { soonest = reminder.date }
        }
        guard let soonest, soonest.timeIntervalSince(now) <= 15 * 60 else { return nil }
        let minutes = max(1, Int((soonest.timeIntervalSince(now) / 60).rounded(.up)))
        return CompactInfo(icon: "calendar", text: "in \(minutes)m", priority: 30)
    }

    func makeView() -> AnyView { AnyView(CalendarView(module: self)) }

    // MARK: Permission

    private func updateAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .notDetermined: access = .notDetermined
        default: access = .denied
        }
    }

    /// Triggered by a button, so the system prompt appears only when the user asks for it.
    func requestAccess() {
        // Accessory apps are not frontmost by default; without this the prompt can hide.
        NSApp.activate(ignoringOtherApps: true)
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.access = granted ? .granted : .denied
                if granted { self?.reload() }
            }
        }
    }

    // MARK: Month navigation

    func shiftMonth(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: displayedMonth) else { return }
        displayedMonth = next
        reload()
    }

    func goToToday() {
        let today = calendar.startOfDay(for: Date())
        selectedDay = today
        displayedMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        reload()
    }

    /// Day cells of the displayed month, padded with nil so weeks line up.
    var monthCells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let weekday = calendar.component(.weekday, from: displayedMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: displayedMonth))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// Weekday initials starting from the user's first weekday.
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    // MARK: Events

    func events(on day: Date) -> [CalendarEvent] { eventsByDay[calendar.startOfDay(for: day)] ?? [] }

    func reminders(on day: Date) -> [Reminder] {
        reminders.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    func reload() {
        guard access == .granted else { return }
        let now = Date()

        // Events of the displayed month, grouped by every day they touch.
        if let month = calendar.dateInterval(of: .month, for: displayedMonth) {
            let predicate = store.predicateForEvents(withStart: month.start, end: month.end, calendars: nil)
            var grouped: [Date: [CalendarEvent]] = [:]
            for event in store.events(matching: predicate).sorted(by: { $0.startDate < $1.startDate }) {
                let item = CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    start: event.startDate, end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: event.calendar.cgColor.map { Color(cgColor: $0) } ?? .blue
                )
                var day = calendar.startOfDay(for: event.startDate)
                let last = calendar.startOfDay(for: event.endDate.addingTimeInterval(-1))
                while day <= max(last, calendar.startOfDay(for: event.startDate)) {
                    grouped[day, default: []].append(item)
                    guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                }
            }
            eventsByDay = grouped
        }

        // Next timed event, for the collapsed notch (independent of the month on screen).
        let soon = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(86400), calendars: nil)
        nextEvent = store.events(matching: soon)
            .filter { !$0.isAllDay && $0.startDate > now }
            .min { $0.startDate < $1.startDate }
            .map { CalendarEvent(id: $0.eventIdentifier ?? "", title: $0.title ?? "", start: $0.startDate,
                                 end: $0.endDate, isAllDay: false, color: .blue) }
        objectWillChange.send() // refresh relative times even when the data is unchanged
    }

    // MARK: Reminders

    /// Creates a reminder on `day` at the time of day taken from `time`.
    func addReminder(title: String, day: Date, time: Date) {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        guard let date = calendar.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: day) else { return }
        let reminder = Reminder(title: text, date: date)
        reminders.append(reminder)
        Notifier.requestAuthorization()
        Notifier.schedule(id: reminder.id.uuidString, title: "Reminder", body: text, at: date)
        saveReminders()
    }

    func toggleDone(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(of: reminder) else { return }
        reminders[index].done.toggle()
        let updated = reminders[index]
        if updated.done {
            Notifier.cancel(id: updated.id.uuidString)
        } else {
            Notifier.schedule(id: updated.id.uuidString, title: "Reminder", body: updated.title, at: updated.date)
        }
        saveReminders()
    }

    func remove(_ reminder: Reminder) {
        Notifier.cancel(id: reminder.id.uuidString)
        reminders.removeAll { $0.id == reminder.id }
        saveReminders()
    }

    private func saveReminders() {
        LocalStore.save(reminders, to: Self.remindersFile)
    }
}
