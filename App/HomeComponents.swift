import SwiftUI
import ScreenshotKit

// MARK: - Due summary (two solid-fill cards, no scary heading)

/// Two compact solid-fill cards on one row over the pale live-wash box:
/// "DUE OVER" (terracotta, left) and "DUE SOON" (black, right), each showing a
/// count. Deliberately heading-less and small — the app should not open on a
/// wall of red reminder boxes; this is a quiet nudge, not a dashboard.
struct DueSummaryRow: View {
    let overCount: Int
    let soonCount: Int
    /// A collection to jump into when tapped (best-effort: the soonest item's).
    let jumpTo: SavedItem?

    var body: some View {
        HStack(spacing: Theme.Space.s1) {
            card(title: "DUE OVER", count: overCount, fill: Theme.Palette.live)
            card(title: "DUE SOON", count: soonCount, fill: Theme.Palette.ink)
        }
        .padding(Theme.Space.s2)
        .background(Theme.Palette.liveWash)
    }

    @ViewBuilder
    private func card(title: String, count: Int, fill: Color) -> some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Text.meta())
                .foregroundStyle(.white.opacity(0.85))
            Text("\(count)")
                .font(Theme.Text.h2())
                .foregroundStyle(.white)
            Text(count == 1 ? "item" : "items")
                .font(Theme.Text.meta())
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(Theme.Space.s2)
        .background(fill)

        if let collection = jumpTo?.collection {
            NavigationLink(value: collection) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

// MARK: - Most recent (horizontal auto-advancing carousel)

/// Compact horizontal carousel of recent saves, interleaved across categories.
/// Auto-advances on a timer; the arrows advance manually. Per the latest
/// direction, manual interaction does NOT permanently stop it — auto-advance
/// stops for the session once the user manually advances it.
struct RecentCarousel: View {
    let items: [SavedItem]

    @State private var index = 0
    @State private var stopped = false
    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: Theme.Space.s1) {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                            slide(for: item)
                                .frame(width: geo.size.width)
                        }
                    }
                    .offset(x: -CGFloat(index) * geo.size.width)
                    .animation(.easeInOut(duration: 0.38), value: index)
                }
                .frame(height: 88)
                .clipped()

                controls
            }
            .onReceive(timer) { _ in
                // Stop-after-interaction: once the user has manually advanced,
                // auto-advance stops for the session.
                if !stopped { advance(1, auto: true) }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: Theme.Space.s2) {
            arrow("‹") { advance(-1) }
            HStack(spacing: 7) {
                ForEach(items.indices, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Theme.Palette.live : Theme.Palette.ink(0.25))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            arrow("›") { advance(1) }
        }
    }

    private func arrow(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(Theme.Text.h3()).foregroundStyle(Theme.Palette.ink)
                .frame(width: 34, height: 34)
                .overlay(Rectangle().stroke(Theme.Palette.ink, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func advance(_ delta: Int, auto: Bool = false) {
        guard !items.isEmpty else { return }
        index = (index + delta + items.count) % items.count
        // Manual taps stop auto-advance for the session.
        if !auto { stopped = true }
    }

    @ViewBuilder private func slide(for item: SavedItem) -> some View {
        if let collection = item.collection {
            NavigationLink(value: collection) { slideBody(item) }.buttonStyle(.plain)
        } else {
            slideBody(item)
        }
    }

    private func slideBody(_ item: SavedItem) -> some View {
        let cat = item.categories.first ?? .other
        return HStack(spacing: Theme.Space.s2) {
            Text(item.mode == .info ? "✎" : "▣")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(cat.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(cat.displayName.uppercased())
                    .font(Theme.Text.meta())
                    .foregroundStyle(cat.color)
                Text(item.summaryLine)
                    .font(Theme.Text.list())
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.s2).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(Theme.Palette.paper)
        .overlay(Rectangle().stroke(Theme.Palette.ink, lineWidth: 1))
    }
}

// MARK: - Looking back bucket (auto cross-fade swap)

/// A time-bucket card whose whole BOX slides vertically through its items,
/// mirroring the Most-recent marquee (which slides horizontally). The heading
/// (label) and item count sit FIXED above the box; only the bordered box moves,
/// so nothing overlaps the heading or the outline. Auto-advances at the
/// marquee's calm pace; a manual swipe stops the auto-advance for the session.
/// Progress is shown with dots (no arrows — a vertical box shouldn't carry
/// left/right controls).
struct BucketCard: View {
    let label: String
    let items: [SavedItem]
    @State private var index = 0
    @State private var stopped = false // manual interaction stops auto-advance
    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    // Fixed slot height for the sliding box.
    private let slotHeight: CGFloat = 92

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            // Fixed heading + count, OUTSIDE the sliding box.
            HStack {
                Text(label.uppercased())
                    .font(Theme.Text.meta()).foregroundStyle(Theme.Palette.live)
                Spacer()
                Text("\(items.count) \(items.count == 1 ? "item" : "items")")
                    .font(Theme.Text.meta()).foregroundStyle(Theme.Palette.ink(0.35))
            }

            // The BOX slides as one unit (like the marquee), vertically.
            GeometryReader { geo in
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { _, it in
                        box(for: it).frame(width: geo.size.width, height: slotHeight)
                    }
                }
                .offset(y: -CGFloat(index) * slotHeight)
                .animation(.easeInOut(duration: 0.45), value: index)
            }
            .frame(height: slotHeight)
            .clipped()
            // Swipe up/down advances; any manual swipe stops auto-advance.
            .gesture(
                DragGesture(minimumDistance: 12).onEnded { g in
                    if items.count > 1 {
                        advance(g.translation.height < 0 ? 1 : -1, manual: true)
                    }
                }
            )

            if items.count > 1 { dots }
        }
        .onReceive(timer) { _ in
            if !stopped, items.count > 1 { advance(1) }
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(items.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? Theme.Palette.live : Theme.Palette.ink(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func advance(_ delta: Int, manual: Bool = false) {
        guard items.count > 1 else { return }
        index = (index + delta + items.count) % items.count
        if manual { stopped = true } // stop auto-advance for the session
    }

    // One bucket item rendered as a bordered box (the sliding unit). Includes
    // the saved image thumbnail for image-mode items so buckets surface real
    // pictures, not just text.
    @ViewBuilder private func box(for it: SavedItem) -> some View {
        if let collection = it.collection {
            NavigationLink(value: collection) { boxBody(it) }.buttonStyle(.plain)
        } else {
            boxBody(it)
        }
    }

    private func boxBody(_ it: SavedItem) -> some View {
        let cat = it.categories.first ?? .other
        return HStack(alignment: .center, spacing: Theme.Space.s2) {
            if it.mode == .image, let data = it.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 60, height: 60).clipped()
                    .overlay(Rectangle().stroke(Theme.Palette.rule, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(cat.displayName.uppercased())
                    .font(Theme.Text.meta()).foregroundStyle(cat.color)
                Text(it.summaryLine)
                    .font(Theme.Text.list()).foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.s2).padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.Palette.paper)
        .overlay(Rectangle().stroke(Theme.Palette.ink, lineWidth: 1))
    }
}
