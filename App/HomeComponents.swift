import SwiftUI
import ScreenshotKit

/// A due/overdue row in "Needs attention".
struct NeedsAttentionRow: View {
    let item: SavedItem

    private var status: DueStatus? { item.dueDate.map { DueStatus.from(dueDate: $0) } }

    var body: some View {
        if let collection = item.collection {
            NavigationLink(value: collection) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let status {
                Text(status.label.uppercased())
                    .font(Theme.Text.meta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(flagColor(status))
            }
            Text(item.summaryLine)
                .font(Theme.Text.body())
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)
            if let cat = item.categories.first {
                Text("\(cat.displayName.uppercased())")
                    .font(Theme.Text.meta())
                    .foregroundStyle(cat.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.s2)
        .background(Theme.Palette.paper)
        .overlay(Rectangle().stroke(Theme.Palette.live, lineWidth: 1))
    }

    private func flagColor(_ s: DueStatus) -> Color {
        switch s {
        case .overdue: return Theme.Palette.overdue
        case .today:   return Theme.Palette.live
        default:       return Theme.Palette.ink
        }
    }
}

/// Compact horizontal marquee of the most recent items across categories.
struct RecentMarquee: View {
    let items: [SavedItem]

    var body: some View {
        TabView {
            ForEach(items) { item in
                slide(for: item)
                    .padding(.horizontal, 2)
            }
        }
        .frame(height: 108)
        .tabViewStyle(.page(indexDisplayMode: .always))
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

/// A time-bucket card that swaps through its items.
struct BucketCard: View {
    let label: String
    let items: [SavedItem]
    @State private var index = 0

    private var item: SavedItem { items[min(index, items.count - 1)] }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            HStack {
                Text(label.uppercased())
                    .font(Theme.Text.meta()).foregroundStyle(Theme.Palette.live)
                Spacer()
                Text("\(items.count) \(items.count == 1 ? "item" : "items")")
                    .font(Theme.Text.meta()).foregroundStyle(Theme.Palette.ink(0.35))
            }

            // Tapping the item content navigates to its collection; the arrows
            // (below) just swap the visible item and don't trigger navigation.
            navigableContent

            if items.count > 1 {
                HStack(spacing: Theme.Space.s2) {
                    Button("‹") { index = (index - 1 + items.count) % items.count }
                    Spacer()
                    Button("›") { index = (index + 1) % items.count }
                }
                .font(Theme.Text.h3())
                .foregroundStyle(Theme.Palette.ink)
                .padding(.top, Theme.Space.s1)
            }
        }
        .padding(Theme.Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.paper)
        .overlay(Rectangle().stroke(Theme.Palette.ink, lineWidth: 1))
    }

    @ViewBuilder private var navigableContent: some View {
        if let collection = item.collection {
            NavigationLink(value: collection) { itemContent }.buttonStyle(.plain)
        } else {
            itemContent
        }
    }

    private var itemContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            let cat = item.categories.first ?? .other
            Text(cat.displayName.uppercased())
                .font(Theme.Text.meta()).foregroundStyle(cat.color)
            Text(item.summaryLine)
                .font(Theme.Text.body()).foregroundStyle(Theme.Palette.ink)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
