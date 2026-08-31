import SwiftUI
import SwiftData
import ScreenshotKit

// Disambiguate from the ObjC runtime's `Category` type.
private typealias Category = ScreenshotKit.Category

/// Browse all collections in a two-column grid, filterable by category chips.
/// Tapping a collection pushes its detail. Reads live from the shared store.
struct CollectionsView: View {
    @Query(sort: \Collection.createdAt, order: .reverse) private var collections: [Collection]
    @State private var filter: Category? = nil

    private var filtered: [Collection] {
        guard let f = filter else { return collections }
        return collections.filter { $0.primaryCategory == f }
    }

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Space.s1),
        GridItem(.flexible(), spacing: Theme.Space.s1),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                Text("Collections")
                    .font(Theme.Text.h2())
                    .foregroundStyle(Theme.Palette.ink)
                    .padding(.horizontal, Theme.Space.s3)
                    .padding(.top, Theme.Space.s2)

                filterChips

                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Space.s1) {
                    ForEach(filtered) { collection in
                        NavigationLink(value: collection) {
                            CollectionCardView(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Space.s3)

                Spacer(minLength: Theme.Space.s4)
            }
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.s1) {
                chip(title: "All", active: filter == nil) { filter = nil }
                ForEach(Category.allCases) { cat in
                    chip(title: cat.displayName, active: filter == cat) { filter = cat }
                }
            }
            .padding(.horizontal, Theme.Space.s3)
        }
    }

    private func chip(title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title.uppercased()).font(Theme.Text.meta())
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(active ? Theme.Palette.paper : Theme.Palette.ink(0.72))
                .background(active ? Theme.Palette.ink : Theme.Palette.paper)
                .overlay(Rectangle().stroke(active ? Theme.Palette.ink : Theme.Palette.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A single collection card: category-colored cover + name + count.
struct CollectionCardView: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(collection.primaryCategory.color)
                .frame(height: 120)
                .overlay(alignment: .bottomLeading) {
                    Text(collection.primaryCategory.displayName.uppercased())
                        .font(Theme.Text.meta())
                        .foregroundStyle(.white)
                        .padding(Theme.Space.s1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(Theme.Text.list()).bold()
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                Text("\(collection.activeCount) saved")
                    .font(Theme.Text.meta())
                    .foregroundStyle(Theme.Palette.ink(0.5))
            }
            .padding(.horizontal, Theme.Space.s2)
            .padding(.vertical, Theme.Space.s1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Palette.paper)
        .overlay(Rectangle().stroke(Theme.Palette.ink, lineWidth: 1))
    }
}
