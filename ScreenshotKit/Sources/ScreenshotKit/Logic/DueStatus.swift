import Foundation

/// Urgency of a due date, for the home "Needs attention" section.
public enum DueStatus: Sendable, Equatable {
    case overdue(days: Int)
    case today
    case soon(days: Int)   // due within the attention window
    case later(days: Int)  // has a due date, but beyond the window

    /// Days ahead that still count as "needs attention".
    public static let attentionWindow = 3

    public var label: String {
        switch self {
        case .overdue(let d) where d == 1: return "Overdue since yesterday"
        case .overdue(let d):              return "\(d) days overdue"
        case .today:                       return "Due today"
        case .soon(let d) where d == 1:    return "Due tomorrow"
        case .soon(let d):                 return "Due in \(d) days"
        case .later(let d):                return "Due in \(d) days"
        }
    }

    /// True when the item should appear in "Needs attention".
    public var needsAttention: Bool {
        switch self {
        case .overdue, .today, .soon: return true
        case .later:                  return false
        }
    }

    /// Compute status from a due date relative to now.
    public static func from(dueDate: Date, now: Date = .now) -> DueStatus {
        let cal = Calendar.current
        let startNow = cal.startOfDay(for: now)
        let startDue = cal.startOfDay(for: dueDate)
        let days = cal.dateComponents([.day], from: startNow, to: startDue).day ?? 0
        if days < 0 { return .overdue(days: -days) }
        if days == 0 { return .today }
        if days <= attentionWindow { return .soon(days: days) }
        return .later(days: days)
    }
}

public extension Array where Element == SavedItem {
    /// Items that need attention (overdue or due soon), most-urgent first.
    func needingAttention(now: Date = .now) -> [SavedItem] {
        compactMap { item -> (SavedItem, Date)? in
            guard let due = item.dueDate, !item.isArchived else { return nil }
            return DueStatus.from(dueDate: due, now: now).needsAttention ? (item, due) : nil
        }
        .sorted { $0.1 < $1.1 } // earliest/most-overdue first
        .map { $0.0 }
    }
}
