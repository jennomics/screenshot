import Foundation
import SwiftData

/// How a screenshot was saved.
public enum SaveMode: String, Codable, Sendable {
    /// The full screenshot image is kept.
    case image
    /// The image is discarded; only the useful extracted text/details are kept.
    /// This is the ADHD-friendly default.
    case info
}

/// A single thing the user saved from a screenshot. This is the central record
/// written by BOTH capture paths (Share Extension + Photos scanner) and read by
/// the main app. It lives in the shared App Group store.
@Model
public final class SavedItem {
    /// Stable identity (useful for notifications, dedupe against the Photos scan).
    @Attribute(.unique) public var id: UUID

    /// When the screenshot was captured/saved. Drives home-screen time bucketing
    /// and recency ordering.
    public var createdAt: Date

    /// image vs info-only.
    public var mode: SaveMode

    /// The user's free-text reason ("why I'm saving this"), optional.
    public var note: String?

    /// The on-device extracted text (OCR + entity extraction). Present for
    /// `.info` saves; may also be present for `.image` saves for search.
    public var extractedText: String?

    /// The screenshot image bytes. Stored externally (not inline in the DB) for
    /// `.image` saves; nil for `.info` saves. `.externalStorage` keeps the
    /// SQLite file small by writing large blobs to the container filesystem.
    @Attribute(.externalStorage) public var imageData: Data?

    /// Where the screenshot came from, if known (e.g. "Safari", "Instagram").
    public var sourceApp: String?

    /// The Photos `PHAsset.localIdentifier` this item was imported from, if it
    /// came via the Photos scanner. Used to dedupe so a screenshot isn't
    /// imported twice. Nil for Share-Extension captures.
    public var sourceAssetID: String?

    /// Categories this item belongs to (multi-select). Stored as raw strings so
    /// the enum can evolve without a migration; mapped via `categories`.
    public var categoryRaw: [String]

    /// Optional due date detected from the text or set by the user. Feeds the
    /// home "Needs attention" section and reminder scheduling.
    public var dueDate: Date?

    /// The source phrase the due date was detected from (e.g. "closes Fri"),
    /// shown in the capture modal so the user can see why a date was proposed.
    public var dueSourcePhrase: String?

    /// Optional reminder/expiry metadata (see `ReminderPlan`).
    public var reminder: ReminderPlan?

    /// The collection this item is filed into, if any. Inverse of
    /// `Collection.items`.
    public var collection: Collection?

    /// When the item was archived (auto-faded after expiry, or manually).
    /// Non-nil = hidden from the main views but recoverable, never hard-deleted.
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        mode: SaveMode,
        note: String? = nil,
        extractedText: String? = nil,
        imageData: Data? = nil,
        sourceApp: String? = nil,
        sourceAssetID: String? = nil,
        categories: [Category] = [],
        dueDate: Date? = nil,
        dueSourcePhrase: String? = nil,
        reminder: ReminderPlan? = nil,
        collection: Collection? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mode = mode
        self.note = note
        self.extractedText = extractedText
        self.imageData = imageData
        self.sourceApp = sourceApp
        self.sourceAssetID = sourceAssetID
        self.categoryRaw = categories.map(\.rawValue)
        self.dueDate = dueDate
        self.dueSourcePhrase = dueSourcePhrase
        self.reminder = reminder
        self.collection = collection
        self.archivedAt = archivedAt
    }

    // MARK: Derived

    /// Typed access to the item's categories.
    public var categories: [Category] {
        get { categoryRaw.compactMap(Category.init(rawValue:)) }
        set { categoryRaw = newValue.map(\.rawValue) }
    }

    public var isArchived: Bool { archivedAt != nil }

    /// A short display line for lists/carousels: prefer the extracted text for
    /// info saves, otherwise the user's note.
    public var summaryLine: String {
        if mode == .info, let t = extractedText, !t.isEmpty { return t }
        return note ?? ""
    }
}
