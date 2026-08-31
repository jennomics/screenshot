#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only sample data. Mirrors the prototype's example items so the app
/// boots with something to render (Home marquee, time buckets, Needs attention)
/// while the real capture pipeline and shared store are being built out.
///
/// Never compiled into release builds (wrapped in `#if DEBUG`).
public enum SampleData {

    /// Insert the sample set if the store has no items yet. Safe to call on
    /// every launch — it no-ops once data exists.
    @MainActor
    public static func seedIfEmpty(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SavedItem>()))?.isEmpty ?? true
        guard existing else { return }
        seed(context)
    }

    /// Delete all items + collections, then re-seed. For the dev menu.
    @MainActor
    public static func reset(_ context: ModelContext) {
        (try? context.fetch(FetchDescriptor<SavedItem>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<Collection>()))?.forEach(context.delete)
        try? context.save()
        seed(context)
    }

    /// Delete everything without re-seeding.
    @MainActor
    public static func wipe(_ context: ModelContext) {
        (try? context.fetch(FetchDescriptor<SavedItem>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<Collection>()))?.forEach(context.delete)
        try? context.save()
    }

    @MainActor
    public static func seed(_ context: ModelContext) {
        func daysAgo(_ n: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -n, to: .now) ?? .now
        }
        func daysAhead(_ n: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: n, to: .now) ?? .now
        }

        // Collections mirroring the prototype.
        let painting = Collection(name: "Painting inspiration", primaryCategory: .inspiration)
        let driversEd = Collection(name: "Driver's ed for Ellie", primaryCategory: .kids)
        let kittenHeels = Collection(name: "Kitten heels", primaryCategory: .shopping)
        let weeknight = Collection(name: "Weeknight dinners", primaryCategory: .recipes)
        let readLater = Collection(name: "Read later", primaryCategory: .readLater)
        let errands = Collection(name: "Errands & to-do", primaryCategory: .todo)
        [painting, driversEd, kittenHeels, weeknight, readLater, errands].forEach(context.insert)

        // Items — spread across time buckets, some with due dates so
        // "Needs attention" has content. (These match the prototype's data.)
        let items: [SavedItem] = [
            // painting
            SavedItem(createdAt: daysAgo(3), mode: .info,
                      note: "The way the light falls on the water here.",
                      extractedText: "Muted terracotta + sage palette · loose brushwork reference",
                      categories: [.inspiration], collection: painting),
            SavedItem(createdAt: daysAgo(9), mode: .info,
                      extractedText: "Wet-on-wet for skies, dry-brush foliage. Artist: @mara.paints.",
                      categories: [.inspiration], collection: painting),

            // driver's ed — due tomorrow (Needs attention)
            SavedItem(createdAt: daysAgo(1), mode: .info,
                      note: "Where to sign Ellie up for driver's ed.",
                      extractedText: "Riverside Driving School · enrollment closes Fri · $480 · (555) 0142",
                      categories: [.todo, .kids],
                      dueDate: daysAhead(1), dueSourcePhrase: "enrollment closes Fri",
                      collection: driversEd),

            // kitten heels — one due soon (Needs attention)
            SavedItem(createdAt: daysAgo(5), mode: .info,
                      note: "These in the tan color. Wait for a sale.",
                      extractedText: "Tan pointed-toe · size up half a size per reviews",
                      categories: [.shopping], collection: kittenHeels),
            SavedItem(createdAt: daysAgo(45), mode: .info,
                      extractedText: "Brand runs a half size small. Free returns within 30 days.",
                      categories: [.shopping], collection: kittenHeels),
            SavedItem(createdAt: daysAgo(120), mode: .info,
                      note: "The pointed-toe pair — sale ends soon.",
                      extractedText: "Sale ends soon per caption",
                      categories: [.shopping],
                      dueDate: daysAhead(2), dueSourcePhrase: "sale ends soon",
                      collection: kittenHeels),

            // recipes
            SavedItem(createdAt: daysAgo(4), mode: .info,
                      extractedText: "Lemon-garlic orzo w/ spinach · 1 pot, ~25 min · @quickdinners",
                      categories: [.recipes], collection: weeknight),
            SavedItem(createdAt: daysAgo(11), mode: .info,
                      extractedText: "Sheet-pan gnocchi + cherry tomatoes + pesto, 425°F 25 min.",
                      categories: [.recipes], collection: weeknight),

            // read later
            SavedItem(createdAt: daysAgo(2), mode: .info,
                      extractedText: "\"How ADHD brains handle time\" — J. Reyes · ~12 min read",
                      categories: [.readLater], collection: readLater),
            SavedItem(createdAt: daysAgo(40), mode: .info,
                      extractedText: "Book stack recommendation from that thread",
                      categories: [.readLater], collection: readLater),
            SavedItem(createdAt: daysAgo(400), mode: .info,
                      extractedText: "\"On slow productivity\" — save for a quiet weekend",
                      categories: [.readLater], collection: readLater),

            // errands — one overdue, one due today (Needs attention)
            SavedItem(createdAt: daysAgo(6), mode: .info,
                      note: "The thing I keep forgetting to order.",
                      extractedText: "Water filter DA29-00020B · ~$32 for 2-pack",
                      categories: [.todo],
                      dueDate: daysAgo(1), dueSourcePhrase: "reminder",
                      collection: errands),
            SavedItem(createdAt: daysAgo(8), mode: .info,
                      note: "Return window closes soon on the jacket.",
                      extractedText: "Return the navy jacket · label printed · Order #4471",
                      categories: [.todo],
                      dueDate: .now, dueSourcePhrase: "return window closes",
                      collection: errands),
        ]
        items.forEach(context.insert)

        try? context.save()
    }
}
#endif
