import SwiftUI

/// Left: month grid you can page through. Right: the selected day's events and
/// reminders, with a field to add a new reminder.
struct CalendarView: View {
    @ObservedObject var module: CalendarModule
    @State private var newTitle = ""
    @State private var newTime = CalendarView.defaultTime()

    private let calendar = Calendar.current

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            monthPane.frame(width: 250)
            dayPane.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
    }

    // MARK: Month grid

    private var monthPane: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                navButton("chevron.left") { module.shiftMonth(by: -1) }
                Text(module.displayedMonth.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                navButton("chevron.right") { module.shiftMonth(by: 1) }
                Button("Today") { module.goToToday() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.orange)
                    .padding(.leading, 4)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(module.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.system(size: 10)).foregroundStyle(.secondary).frame(height: 16)
                }
                ForEach(Array(module.monthCells.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 24) }
                }
            }
            // Swipe sideways (trackpad) to change month.
            .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    module.shiftMonth(by: value.translation.width < 0 ? 1 : -1)
                }
            })
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: module.selectedDay)
        let today = calendar.isDateInToday(day)
        let hasEvents = !module.events(on: day).isEmpty
        let hasReminders = module.reminders(on: day).contains { !$0.done }
        return Button { module.selectedDay = calendar.startOfDay(for: day) } label: {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 12, weight: today ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(selected ? Color.black : (today ? Color.orange : Color.white))
                HStack(spacing: 2) {
                    Circle().fill(Color.blue).frame(width: 3, height: 3).opacity(hasEvents ? 1 : 0)
                    Circle().fill(Color.orange).frame(width: 3, height: 3).opacity(hasReminders ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 24)
            .background(Circle().fill(selected ? Color.white : .clear).frame(width: 26, height: 26))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Selected day

    private var dayPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(module.selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.system(size: 13, weight: .semibold))

            dayList
                .frame(maxHeight: .infinity, alignment: .top)

            addReminderRow
        }
    }

    @ViewBuilder
    private var dayList: some View {
        let events = module.events(on: module.selectedDay)
        let reminders = module.reminders(on: module.selectedDay)
        if events.isEmpty && reminders.isEmpty {
            VStack(spacing: 6) {
                Text("Nothing planned").font(.system(size: 12)).foregroundStyle(.secondary)
                if module.access == .notDetermined {
                    Button("Show my calendar events") { module.requestAccess() }.controlSize(.small)
                } else if module.access == .denied {
                    Button("Calendar access is off · open settings") { PermissionHelper.openCalendarSettings() }
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity).padding(.top, 14)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(events) { eventRow($0) }
                    ForEach(reminders) { reminderRow($0) }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(event.isAllDay ? "All day"
                     : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.07)))
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 8) {
            Button { module.toggleDone(reminder) } label: {
                Image(systemName: reminder.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(reminder.done ? Color.green : Color.orange)
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text(reminder.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    .strikethrough(reminder.done)
                Text("Reminder · \(reminder.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .opacity(reminder.done ? 0.5 : 1)
            Spacer()
            Button { module.remove(reminder) } label: {
                Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.orange.opacity(0.12)))
    }

    // MARK: Add reminder

    private var addReminderRow: some View {
        HStack(spacing: 6) {
            TextField("Remind me…", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
            DatePicker("", selection: $newTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: 84)
            Button(action: add) { Image(systemName: "plus") }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .controlSize(.small)
    }

    private func add() {
        module.addReminder(title: newTitle, day: module.selectedDay, time: newTime)
        newTitle = ""
    }

    /// Next full hour, a sensible default for "remind me later".
    private static func defaultTime() -> Date {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: next), minute: 0, second: 0, of: next) ?? next
    }
}
