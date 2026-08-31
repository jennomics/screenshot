import Foundation

/// Recency windows for the home "Looking back" section. Ordered most-recent →
/// oldest. Each item lands in the first bucket whose window contains it; the
/// home screen shows, per bucket, only items not already surfaced by an earlier
/// bucket, so each card reveals new content. Empty buckets are not rendered.
public enum TimeBucket: String, CaseIterable, Identifiable, Sendable {
    case yesterday, thisWeek, lastWeek, thisMonth, lastMonth
    case thisQuarter, lastQuarter, thisYear, lastYear

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .yesterday:   return "Yesterday"
        case .thisWeek:    return "This week"
        case .lastWeek:    return "Last week"
        case .thisMonth:   return "This month"
        case .lastMonth:   return "Last month"
        case .thisQuarter: return "This quarter"
        case .lastQuarter: return "Last quarter"
        case .thisYear:    return "This year"
        case .lastYear:    return "Last year"
        }
    }

    /// Inclusive day-offset range from "today".
    public var range: ClosedRange<Int> {
        switch self {
        case .yesterday:   return 1...1
        case .thisWeek:    return 2...6
        case .lastWeek:    return 7...13
        case .thisMonth:   return 14...29
        case .lastMonth:   return 30...59
        case .thisQuarter: return 60...89
        case .lastQuarter: return 90...179
        case .thisYear:    return 180...364
        case .lastYear:    return 365...Int.max
        }
    }

    /// Bucket a set of items by recency, dropping items already used by a more-
    /// recent bucket and dropping empty buckets. Returns buckets in display
    /// order, each paired with its items (newest first).
    public static func partition(_ items: [SavedItem], now: Date = .now) -> [(bucket: TimeBucket, items: [SavedItem])] {
        let sorted = items
            .filter { !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
        let cal = Calendar.current
        var used = Set<UUID>()
        var result: [(TimeBucket, [SavedItem])] = []

        for bucket in TimeBucket.allCases {
            let inWindow = sorted.filter { item in
                guard !used.contains(item.id) else { return false }
                let days = cal.dateComponents([.day], from: item.createdAt, to: now).day ?? 0
                return bucket.range.contains(days)
            }
            guard !inWindow.isEmpty else { continue }
            inWindow.forEach { used.insert($0.id) }
            result.append((bucket, inWindow))
        }
        return result
    }
}
