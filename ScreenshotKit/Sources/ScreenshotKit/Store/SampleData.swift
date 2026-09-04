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
        let driversEd = Collection(name: "Driver's ed for Vivian", primaryCategory: .kids)
        let kittenHeels = Collection(name: "Kitten heels", primaryCategory: .shopping)
        let weeknight = Collection(name: "Weeknight dinners", primaryCategory: .recipes)
        let readLater = Collection(name: "Read later", primaryCategory: .readLater)
        let errands = Collection(name: "Errands & to-do", primaryCategory: .todo)
        [painting, driversEd, kittenHeels, weeknight, readLater, errands].forEach(context.insert)

        // Items — spread across time buckets, some with due dates so
        // "Needs attention" has content. (These match the prototype's data.)
        let items: [SavedItem] = [
            // painting — kept as an IMAGE (a visual reference you want to look at)
            SavedItem(createdAt: daysAgo(3), mode: .image,
                      note: "Sunset colors for squeegee art.",
                      imageData: seedImage("painting"),
                      categories: [.inspiration], collection: painting),
            // an upcoming workshop — IMAGE with a real future due date (Oct 17, 2026)
            SavedItem(createdAt: daysAgo(9), mode: .image,
                      note: "Encaustic Art workshop I want to sign up for.",
                      imageData: seedImage("art-workshop"),
                      categories: [.inspiration],
                      dueDate: specificDate(year: 2026, month: 10, day: 17),
                      dueSourcePhrase: "October 17, 2026",
                      collection: painting),
            // an INFO-kept save in the same collection, so the collection detail
            // shows an image card and an extracted-text card side by side (demo
            // wants both kinds visible).
            SavedItem(createdAt: daysAgo(6), mode: .info,
                      extractedText: "Sacramento Fine Arts · Encaustic Art workshop · Sat Oct 17, 10–2 · $95 · bring an apron",
                      categories: [.inspiration], collection: painting),

            // driver's ed — due tomorrow (Needs attention)
            SavedItem(createdAt: daysAgo(1), mode: .info,
                      note: "Where to sign Vivian up for driver's ed.",
                      extractedText: "Riverside Driving School · enrollment closes Fri · $480 · (555) 0142",
                      categories: [.todo, .kids],
                      dueDate: daysAhead(1), dueSourcePhrase: "enrollment closes Fri",
                      collection: driversEd),
            SavedItem(createdAt: daysAgo(1), mode: .image,
                      note: "Sign Vivian up by tomorrow.",
                      imageData: seedImage("drivers-ed"),
                      categories: [.kids], collection: driversEd),

            // kitten heels — kept as an IMAGE (the actual pair you saw)
            SavedItem(createdAt: daysAgo(5), mode: .image,
                      note: "Quince · $84 · black leather slingback.",
                      imageData: seedImage("kitten-heels"),
                      categories: [.shopping], collection: kittenHeels),
            SavedItem(createdAt: daysAgo(45), mode: .info,
                      extractedText: "Quince kitten heels · $84 · black leather · slingback · runs true to size",
                      categories: [.shopping], collection: kittenHeels),
            SavedItem(createdAt: daysAgo(120), mode: .info,
                      note: "Wait for a sale before buying.",
                      extractedText: "Free returns within 30 days",
                      categories: [.shopping],
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

    /// Loads a bundled seed screenshot's bytes by base name (e.g. "painting").
    /// Images live in App/Resources/SeedImages and ship in the app bundle.
    /// Returns nil if not found (the detail view falls back to a placeholder).
    static func seedImage(_ name: String) -> Data? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg") {
            return try? Data(contentsOf: url)
        }
        return nil
    }

    /// A concrete calendar date (for fixed events like the workshop).
    static func specificDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 9
        return Calendar.current.date(from: c) ?? .now
    }
}
#endif
