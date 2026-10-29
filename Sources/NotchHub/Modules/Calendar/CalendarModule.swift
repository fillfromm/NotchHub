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

/// Upcoming events from the system calendars (EventKit, read-only).
final class CalendarModule: NotchModule, ObservableObject {
    enum Access { case notDetermined, granted, denied }

    let id = "calendar"
    let title = "Calendar"
    let icon = "calendar"

    @Published private(set) var access: Access = .notDetermined
    @Published private(set) var events: [CalendarEvent] = []

    private let store = EKEventStore()
    private var timer: Timer?

    init() {
        updateAccess()
        if access == .granted { reload() }

        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.reload()
        }
        // Keeps "in 12 min" labels and the compact info fresh.
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.access == .granted { self.reload() }
            }
        }
    }

    deinit { timer?.invalidate() }

    /// Next event that is still ahead; shown in the collapsed notch if it starts within 15 minutes.
    var compactInfo: CompactInfo? {
        guard access == .granted,
              let next = events.first(where: { !$0.isAllDay && $0.start > Date() }),
              next.start.timeIntervalSinceNow <= 15 * 60 else { return nil }
        let minutes = max(1, Int((next.start.timeIntervalSinceNow / 60).rounded(.up)))
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

    // MARK: Loading

    func reload() {
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(7 * 86400), calendars: nil)
        let found = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    start: event.startDate, end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: event.calendar.cgColor.map { Color(cgColor: $0) } ?? .blue
                )
            }
        events = Array(found)
        objectWillChange.send() // refresh relative times even when the list is unchanged
    }
}

struct CalendarView: View {
    @ObservedObject var module: CalendarModule

    var body: some View {
        switch module.access {
        case .notDetermined:
            message("Show your next events here.", button: "Allow calendar access") { module.requestAccess() }
        case .denied:
            message("Calendar access is turned off for NotchHub.", button: "Open Privacy settings") {
                PermissionHelper.openCalendarSettings()
            }
        case .granted:
            if module.events.isEmpty {
                message("No events in the next 7 days.", button: nil) {}
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(module.events) { row($0) }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, 6)
            }
        }
    }

    private func row(_ event: CalendarEvent) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(timeText(event)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(relative(event)).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
    }

    private func timeText(_ event: CalendarEvent) -> String {
        let day = event.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if event.isAllDay { return "\(day) · All day" }
        let time = "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))"
        return Calendar.current.isDateInToday(event.start) ? time : "\(day) · \(time)"
    }

    private func relative(_ event: CalendarEvent) -> String {
        if event.start <= Date() { return "now" }
        let minutes = Int(event.start.timeIntervalSinceNow / 60)
        if minutes < 60 { return "in \(max(1, minutes)) min" }
        if minutes < 24 * 60 { return "in \(minutes / 60) h" }
        return ""
    }

    private func message(_ text: String, button: String?, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar").font(.system(size: 24)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 12)).multilineTextAlignment(.center)
            if let button { Button(button, action: action).controlSize(.small) }
        }
    }
}
