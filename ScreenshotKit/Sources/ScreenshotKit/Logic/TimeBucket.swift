import Foundation

/// Recency windows for the home "Looking back" section. Ordered most-recent →
/// oldest. Each item lands in the first bucket whose window contains it; the
/// home screen shows, per bucket, only items not already surfaced by an earlier
/// bucket, so each card reveals new content. Empty buckets are not rendered.
public enum TimeBucket: String, CaseIterable, Identifiable, Sendable {
    case lastWeek, lastMonth, lastQuarter, lastYear

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .lastWeek:    return "Last week"
        case .lastMonth:   return "Last month"
        case .lastQuarter: return "Last quarter"
        case .lastYear:    return "Last year"
        }
    }

    /// Inclusive day-offset range from "today". The four windows are gapless and
    /// cover everything from 1 day ago onward, so every non-archived item lands
    /// in exactly one bucket (Last year is the catch-all for anything older).
    public var range: ClosedRange<Int> {
        switch self {
        case .lastWeek:    return 1...13
        case .lastMonth:   return 14...59
        case .lastQuarter: return 60...179
        case .lastYear:    return 180...Int.max
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
