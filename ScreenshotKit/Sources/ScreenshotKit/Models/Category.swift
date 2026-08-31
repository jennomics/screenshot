import Foundation

/// A category a saved item can belong to. An item can have MANY categories
/// (see `SavedItem.categories`) — e.g. an errand *for* the kids is both
/// `.todo` and `.kids`.
///
/// Kept as a stable string-backed enum rather than a stored model so category
/// identity never drifts and is trivial to reason about across the app and the
/// extension. Display metadata (name, color) is derived, not stored.
public enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case inspiration
    case todo
    case shopping
    case kids
    case recipes
    case readLater
    case other

    public var id: String { rawValue }

    /// Human-facing name.
    public var displayName: String {
        switch self {
        case .inspiration: return "Inspiration"
        case .todo:        return "To-do / Errands"
        case .shopping:    return "Shopping"
        case .kids:        return "Kids"
        case .recipes:     return "Recipes"
        case .readLater:   return "Read later"
        case .other:       return "Other"
        }
    }

    /// Hex color used for the category's cover/accent. Resolved to a SwiftUI
    /// Color by the design system layer.
    public var colorHex: String {
        switch self {
        case .inspiration: return "A8512C" // partyswoop "live"
        case .todo:        return "1C1C1A"
        case .shopping:    return "6B4E9E"
        case .kids:        return "3C6E57"
        case .recipes:     return "B08114"
        case .readLater:   return "2C5A78"
        case .other:       return "55544F"
        }
    }
}
