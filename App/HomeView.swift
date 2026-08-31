import SwiftUI
import SwiftData
import ScreenshotKit

/// Home screen: Needs attention (if any) → compact recent marquee → time
/// buckets. Mirrors the prototype layout. Reads live from the shared store.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedItem.createdAt, order: .reverse) private var items: [SavedItem]
    @State private var showSettings = false

    private var due: [SavedItem] { items.needingAttention() }
    private var recent: [SavedItem] { Array(items.filter { !$0.isArchived }.prefix(8)) }
    private var buckets: [(bucket: TimeBucket, items: [SavedItem])] { TimeBucket.partition(items) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                header

                if !due.isEmpty {
                    Section_(title: "Needs attention", background: Theme.Palette.liveWash) {
                        ForEach(due) { NeedsAttentionRow(item: $0) }
                    }
                }

                Section_(title: "Most recent") {
                    RecentMarquee(items: recent)
                }

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
            SampleData.seedIfEmpty(context)
            #endif
            // Ask for notification permission once so due-date reminders can fire.
            await NotificationScheduler.requestAuthorization()
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
