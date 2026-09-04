import Foundation

public extension SavedItem {
    /// Interleave items across their primary category by recency, round-robin:
    /// the newest of category A, then newest of B, then C, then the 2nd-newest
    /// of A, and so on. This keeps the "Most recent" highlight reel from
    /// clumping several items of one category together.
    ///
    /// An item's grouping key is its first category (its primary). Within each
    /// category, items stay in the input order (callers pass newest-first).
    /// Categories are visited in order of each group's most-recent item, so the
    /// very newest save leads.
    static func interleavedByCategory(_ items: [SavedItem]) -> [SavedItem] {
        // Preserve incoming order (expected newest-first) within each group.
        var groups: [Category: [SavedItem]] = [:]
        var groupOrder: [Category] = []
        for item in items {
            let key = item.categories.first ?? .other
            if groups[key] == nil { groups[key] = []; groupOrder.append(key) }
            groups[key]?.append(item)
        }

        var result: [SavedItem] = []
        var round = 0
        var added = true
        while added {
            added = false
            for cat in groupOrder {
                if let bucket = groups[cat], round < bucket.count {
                    result.append(bucket[round])
                    added = true
                }
            }
            round += 1
        }
        return result
    }
}
