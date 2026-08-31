import Foundation
import SwiftData

/// A named, Pinterest-style grouping of saved items (e.g. "Kitten heels",
/// "Painting inspiration"). Collections are created explicitly or proposed by
/// the app when a cluster of similar items builds up.
@Model
public final class Collection {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date

    /// The collection's primary category, used for the cover color/label.
    public var primaryCategoryRaw: String

    /// Items filed into this collection. Deleting a collection nullifies the
    /// items' `collection` link rather than deleting the items themselves.
    @Relationship(deleteRule: .nullify, inverse: \SavedItem.collection)
    public var items: [SavedItem]

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        primaryCategory: Category = .other,
        items: [SavedItem] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.primaryCategoryRaw = primaryCategory.rawValue
        self.items = items
    }

    public var primaryCategory: Category {
        get { Category(rawValue: primaryCategoryRaw) ?? .other }
        set { primaryCategoryRaw = newValue.rawValue }
    }

    /// Count of items not archived — what the UI shows.
    public var activeCount: Int { items.filter { !$0.isArchived }.count }
}
