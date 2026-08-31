#if canImport(UserNotifications)
import Foundation
import UserNotifications

/// Schedules the gentle, ADHD-oriented reminders. Local only — nothing leaves
/// the device. A `SavedItem` with a due date gets a notification at its
/// reminder fire time (or at the start of the due day if no explicit reminder).
public enum NotificationScheduler {

    /// Ask for permission to post local notifications. Safe to call repeatedly.
    @discardableResult
    public static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schedule (or reschedule) the reminder for an item. Uses the item's
    /// `reminder.fireDate` if present, otherwise 9am on the due day. No-ops if
    /// there's nothing to remind about or the time is in the past.
    public static func schedule(for item: SavedItem, now: Date = .now) async {
        guard let fireDate = fireDate(for: item), fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: item)
        content.body = item.summaryLine.isEmpty ? "Tap to review what you saved." : item.summaryLine
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = item.reminder?.notificationID ?? item.id.uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Cancel a pending reminder for an item (e.g. when it's archived/completed).
    public static func cancel(for item: SavedItem) {
        let id = item.reminder?.notificationID ?? item.id.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: helpers

    /// When to fire: explicit reminder time, else 9am on the due day.
    static func fireDate(for item: SavedItem) -> Date? {
        if let r = item.reminder { return r.fireDate }
        guard let due = item.dueDate else { return nil }
        let cal = Calendar.current
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
    }

    static func reminderTitle(for item: SavedItem) -> String {
        if let due = item.dueDate {
            switch DueStatus.from(dueDate: due) {
            case .overdue: return "Still open — was due"
            case .today:   return "Due today"
            case .soon:    return "Coming up soon"
            case .later:   return "A saved reminder"
            }
        }
        return "A saved reminder"
    }
}
#endif
