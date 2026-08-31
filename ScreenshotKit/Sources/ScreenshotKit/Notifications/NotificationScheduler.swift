#if canImport(UserNotifications)
import Foundation
import UserNotifications

/// A fully-`Sendable` snapshot of the reminder-relevant fields of a `SavedItem`.
///
/// We deliberately never pass the `@Model` object (which is not `Sendable` and
/// is bound to its owning actor) across a concurrency boundary. The caller
/// extracts these plain values synchronously on its own actor, then hands the
/// snapshot to the async scheduler. This is the correct, Swift-6-clean pattern.
public struct ReminderRequest: Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var fireDate: Date

    public init(id: String, title: String, body: String, fireDate: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
    }
}

/// Schedules the gentle, ADHD-oriented reminders. Local only — nothing leaves
/// the device.
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

    /// Build a `ReminderRequest` from an item, or nil if there's nothing to
    /// schedule / the fire time is in the past. Call this synchronously on the
    /// actor that owns the model (e.g. `@MainActor`), then pass the result to
    /// `schedule(_:)`.
    public static func request(for item: SavedItem, now: Date = .now) -> ReminderRequest? {
        guard let fireDate = fireDate(for: item), fireDate > now else { return nil }
        let id = item.reminder?.notificationID ?? item.id.uuidString
        let body = item.summaryLine.isEmpty ? "Tap to review what you saved." : item.summaryLine
        return ReminderRequest(id: id, title: reminderTitle(for: item), body: body, fireDate: fireDate)
    }

    /// Schedule (or reschedule) a reminder from a Sendable request.
    public static func schedule(_ req: ReminderRequest) async {
        let content = UNMutableNotificationContent()
        content.title = req.title
        content.body = req.body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: req.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: req.id, content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Cancel a pending reminder by its id (e.g. `item.id.uuidString` or the
    /// reminder's `notificationID`). Extract the id synchronously at the call site.
    public static func cancel(id: String) {
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
