import Foundation

/// Heuristic, on-device category suggestion from OCR'd text.
///
/// v1 is a transparent keyword/scoring model — no network, no ML download,
/// fully predictable and easy to tune. The `SavedItem` extraction hook can be
/// upgraded to a Core ML text classifier or an on-device embedding model later
/// without changing the call site.
public enum CategorySuggester {

    /// Keyword cues per category. Matching is case-insensitive, word-ish.
    private static let cues: [Category: [String]] = [
        .shopping:    ["$", "sale", "cart", "checkout", "order #", "shipping", "returns", "size", "buy", "price", "discount", "coupon"],
        .recipes:     ["recipe", "ingredients", "min", "oven", "bake", "tbsp", "tsp", "cup", "cook", "preheat", "serves"],
        .kids:        ["kids", "school", "enrollment", "daughter", "son", "teacher", "class", "camp", "pediatric", "playdate"],
        .todo:        ["due", "deadline", "reminder", "appointment", "renew", "register", "form", "pay", "bill", "return", "cancel"],
        .readLater:   ["min read", "article", "essay", "author", "read", "blog", "newsletter", "thread", "book"],
        .inspiration: ["palette", "design", "inspo", "aesthetic", "mood", "reference", "art", "paint", "color", "outfit", "decor"],
    ]

    /// Result of a suggestion: the top pick plus ranked alternates.
    public struct Suggestion: Sendable, Equatable {
        public var top: Category
        public var alternates: [Category]
        public init(top: Category, alternates: [Category]) {
            self.top = top
            self.alternates = alternates
        }
    }

    /// Suggest categories for the given text. Always returns a top pick (falls
    /// back to `.other`) plus up to `maxAlternates` distinct runners-up.
    public static func suggest(for text: String, maxAlternates: Int = 2) -> Suggestion {
        let lower = text.lowercased()

        var scores: [Category: Int] = [:]
        for (cat, words) in cues {
            var score = 0
            for w in words where lower.contains(w) { score += 1 }
            if score > 0 { scores[cat] = score }
        }

        // Ranked by score desc, then by a stable category order for ties.
        let order = Category.allCases
        let ranked = scores
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return (order.firstIndex(of: lhs.key) ?? 99) < (order.firstIndex(of: rhs.key) ?? 99)
            }
            .map(\.key)

        guard let top = ranked.first else {
            // Nothing matched — suggest .other, offer a couple of common defaults.
            return Suggestion(top: .other, alternates: [.readLater, .todo])
        }

        var alternates = Array(ranked.dropFirst().prefix(maxAlternates))
        // Pad alternates with sensible defaults if we found only one match.
        if alternates.count < maxAlternates {
            for fallback in [Category.readLater, .todo, .shopping] where alternates.count < maxAlternates {
                if fallback != top && !alternates.contains(fallback) { alternates.append(fallback) }
            }
        }
        return Suggestion(top: top, alternates: alternates)
    }
}
