import AppKit
import UserNotifications

/// Thin wrapper over user notifications + a sound, used when timers finish.
enum Notifier {
    /// Notifications need a real app bundle; they crash under a bare `swift run`.
    private static var available: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Lets banners show even while the app counts as "active" (an accessory app often does).
    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        static let shared = Delegate()
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
            handler([.banner, .sound])
        }
    }

    static func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current().delegate = Delegate.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(title: String, body: String) {
        NSSound(named: "Glass")?.play()
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Schedules a notification for a future date; it is delivered even if the app is closed by then.
    static func schedule(id: String, title: String, body: String, at date: Date) {
        guard available, date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(id: String) {
        guard available else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
