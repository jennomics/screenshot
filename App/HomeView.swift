import SwiftUI
import SwiftData
import ScreenshotKit

/// Home screen. Deliberately delight-first, not a reminder dashboard: it opens
/// on a highlight reel of what you've saved (Most recent), then a quiet,
/// heading-less pair of due summaries, then the "Looking back" time buckets.
/// Reads live from the shared store.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedItem.createdAt, order: .reverse) private var items: [SavedItem]
    @State private var showSettings = false

    private var due: [SavedItem] { items.needingAttention() }
    // Most recent: interleaved across categories by recency (cat1.1, cat2.1,
    // cat3.1, cat1.2, ...) so the highlight reel doesn't clump one category.
    private var recent: [SavedItem] {
        SavedItem.interleavedByCategory(items.filter { !$0.isArchived })
    }
    private var buckets: [(bucket: TimeBucket, items: [SavedItem])] { TimeBucket.partition(items) }

    // Split the due items into overdue-or-today vs due-soon for the two summary
    // cards.
    private var dueOver: [SavedItem] {
        due.filter { item in
            guard let d = item.dueDate else { return false }
            switch DueStatus.from(dueDate: d) { case .overdue, .today: return true; default: return false }
        }
    }
    private var dueSoon: [SavedItem] {
        due.filter { item in
            guard let d = item.dueDate else { return false }
            if case .soon = DueStatus.from(dueDate: d) { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                header

                // 1. Highlight reel first — the delightful part.
                Section_(title: "Most recent") {
                    RecentCarousel(items: recent)
                }

                // 2. Quiet due summaries — no scary "NEEDS ATTENTION" heading,
                //    just two small cards on the pale live-wash. Only shown when
                //    there's actually something due.
                if !dueOver.isEmpty || !dueSoon.isEmpty {
                    DueSummaryRow(overCount: dueOver.count, soonCount: dueSoon.count,
                                  jumpTo: dueSoon.first ?? dueOver.first)
                }

                // 3. Looking back — time buckets that swap through their items.
                Section_(title: "Looking back") {
                    ForEach(buckets, id: \.bucket.id) { entry in
                        BucketCard(label: entry.bucket.label, items: entry.items)
                    }
                }

                Spacer(minLength: Theme.Space.s5)
            }
            .padding(.horizontal, Theme.Space.s3)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .tint(Theme.Palette.ink)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task {
            #if DEBUG
            // Deterministic capture (R7): when launched by the video pipeline's
            // XCUITests with -uiTestSeed, wipe and re-seed so every recording
            // starts from identical state. Otherwise seed only if empty.
            let uiTestSeed = ProcessInfo.processInfo.arguments.contains("-uiTestSeed")
            if uiTestSeed {
                SampleData.reset(context)
            } else {
                SampleData.seedIfEmpty(context)
            }
            // Skip the permission prompt under UI-test capture so no system
            // dialog interrupts the recording.
            if !uiTestSeed {
                await NotificationScheduler.requestAuthorization()
            }
            #else
            // Ask for notification permission once so due-date reminders can fire.
            await NotificationScheduler.requestAuthorization()
            #endif
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A GENTLE CATCH-UP")
                .font(Theme.Text.meta())
                .foregroundStyle(Theme.Palette.ink(0.5))
            Text("Here's what caught your eye.")
                .font(Theme.Text.h1())
                .foregroundStyle(Theme.Palette.ink)
        }
        .padding(.top, Theme.Space.s4)
    }
}

/// A labeled section wrapper (kept tiny; not the real component library yet).
private struct Section_<Content: View>: View {
    let title: String
    var background: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            Text(title.uppercased())
                .font(Theme.Text.meta())
                .foregroundStyle(Theme.Palette.ink(0.5))
            content
        }
        .padding(background == nil ? 0 : Theme.Space.s2)
        .background(background ?? .clear)
    }
}
