import Foundation

/// Reminder + implied expiry for a saved item. A `Codable` value type stored
/// inline on `SavedItem` (SwiftData persists Codable structs on @Model classes).
///
/// The core ADHD-oriented idea: a time-sensitive save becomes obsolete shortly
/// after its reminder, so it can auto-fade (archive) instead of piling up.
public struct ReminderPlan: Codable, Sendable, Hashable {
    /// When to fire the local notification.
    public var fireDate: Date

    /// When the item should auto-archive if not acted on. Derived from the
    /// reminder choice (e.g. "Tomorrow morning" implies "fades in 2 days").
    public var expiresAt: Date?

    /// The identifier of the scheduled `UNNotificationRequest`, so it can be
    /// cancelled/rescheduled.
    public var notificationID: String

    public init(fireDate: Date, expiresAt: Date? = nil, notificationID: String = UUID().uuidString) {
        self.fireDate = fireDate
        self.expiresAt = expiresAt
        self.notificationID = notificationID
    }
}
