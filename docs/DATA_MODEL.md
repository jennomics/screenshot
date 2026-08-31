# Data model — ScreenshotKit

The SwiftData models that make up the shared on-device store. Source lives in
`ScreenshotKit/Sources/ScreenshotKit/Models/`. Everything is persisted locally
in the App Group container; nothing syncs off-device in v1.

## Overview

| Type          | Kind                | Role                                             |
|---------------|---------------------|--------------------------------------------------|
| `SavedItem`   | `@Model` class      | One saved screenshot (image OR extracted info)   |
| `Collection`  | `@Model` class      | A named, Pinterest-style group of items          |
| `Category`    | `enum` (string)     | One of a fixed set of purposes; items have many  |
| `SaveMode`    | `enum`              | `.image` vs `.info`                              |
| `ReminderPlan`| `Codable` struct    | Reminder fire date + implied expiry, stored inline|

Domain logic lives beside the models: `TimeBucket` (home "Looking back"
bucketing) and `DueStatus` (home "Needs attention" urgency).

## `SavedItem` — the central record

Written by both capture paths, read by the app.

```swift
@Model
final class SavedItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date               // recency / time bucketing
    var mode: SaveMode                // .image or .info
    var note: String?                 // free-text "why I'm saving this"
    var extractedText: String?        // OCR / entity extraction (info saves)
    @Attribute(.externalStorage) var imageData: Data?   // image saves only
    var sourceApp: String?            // "Safari", "Instagram", …
    var categoryRaw: [String]         // multi-select; mapped to [Category]
    var dueDate: Date?                // detected or user-set
    var dueSourcePhrase: String?      // e.g. "closes Fri" — why a date was proposed
    var reminder: ReminderPlan?       // reminder + expiry
    var collection: Collection?       // inverse of Collection.items
    var archivedAt: Date?             // faded/expired but recoverable (never hard-deleted)
}
```

Design choices:
- **`mode` captures your core insight** — most saves don't need the image, just
  the information. `.info` is the ADHD-friendly default; it stores
  `extractedText` and skips `imageData`.
- **Images use `.externalStorage`** so large blobs live on the filesystem and
  keep the SQLite file small and fast.
- **Categories are multi-valued**, stored as raw strings and mapped through the
  `categories` computed property, so the `Category` enum can gain cases without
  a schema migration. Supports "an errand *for* the kids" = `[.todo, .kids]`.
- **`dueSourcePhrase`** exists so the capture modal can show *why* a due date
  was proposed ("Detected: 'closes Fri'"), which builds trust in the automation.
- **`archivedAt` instead of deletion** — expired/faded items move to a
  recoverable archive; nothing you saved is ever truly lost.

## `Collection`

```swift
@Model
final class Collection {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var primaryCategoryRaw: String     // cover color/label
    @Relationship(deleteRule: .nullify, inverse: \SavedItem.collection)
    var items: [SavedItem]
}
```

Deleting a collection **nullifies** the link on its items rather than deleting
them — the items survive, just uncategorized into a collection.

## `Category`

Stable, string-backed enum (`inspiration, todo, shopping, kids, recipes,
readLater, other`). Carries `displayName` and `colorHex`; the design layer maps
`colorHex` to a SwiftUI `Color`. Kept as an enum (not a stored model) so
identity never drifts across app and extension.

## `ReminderPlan`

```swift
struct ReminderPlan: Codable, Sendable, Hashable {
    var fireDate: Date          // when the local notification fires
    var expiresAt: Date?        // when to auto-archive if not acted on
    var notificationID: String  // to cancel/reschedule the UNNotificationRequest
}
```

Encodes the ADHD-oriented rule: a time-sensitive save becomes obsolete shortly
after its reminder, so `expiresAt` drives auto-fade.

## Domain logic (not models, but part of the layer)

- **`TimeBucket.partition(_:)`** — buckets items into Yesterday → Last year,
  drops items already shown in a more-recent bucket, and drops empty buckets.
  (Unit-tested.)
- **`DueStatus.from(dueDate:)`** — overdue / today / soon / later, with labels
  and an `attentionWindow`. `Array<SavedItem>.needingAttention()` returns the
  home "Needs attention" list, most-urgent first. (Unit-tested.)

## Verification note

The pure domain logic (bucketing, due status) is unit-tested and was verified to
compile and pass. The `@Model` types require Xcode's Swift toolchain to build
(the `@Model` macro plugin ships with Xcode, not the standalone Command Line
Tools). See `docs/BUILD.md`.
