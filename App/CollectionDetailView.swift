import SwiftUI
import SwiftData
import ScreenshotKit

/// A collection's items: image saves render the picture; info-kept saves render
/// the extracted text with a terracotta rule and an "Info kept" badge. Matches
/// the prototype's collection detail.
struct CollectionDetailView: View {
    let collection: Collection

    private var items: [SavedItem] {
        collection.items
            .filter { !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                if items.isEmpty {
                    Text("Nothing here yet.")
                        .font(Theme.Text.body())
                        .foregroundStyle(Theme.Palette.ink(0.5))
                        .padding(.top, Theme.Space.s3)
                } else {
                    ForEach(items) { ItemCardView(item: $0, accent: collection.primaryCategory.color) }
                }
                Spacer(minLength: Theme.Space.s4)
            }
            .padding(Theme.Space.s3)
        }
        .background(Theme.Palette.paper.ignoresSafeArea())
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One saved item card.
struct ItemCardView: View {
    let item: SavedItem
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if item.mode == .image, let data = item.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(height: 160).clipped()
            } else if item.mode == .image {
                // Image save without loaded bytes (e.g. interim mode) — placeholder.
                Rectangle().fill(accent).frame(height: 160)
                    .overlay(Text("SCREENSHOT").font(Theme.Text.meta()).foregroundStyle(.white))
            }

            VStack(alignment: .leading, spacing: 10) {
                if let note = item.note, !note.isEmpty {
                    Text(note).font(Theme.Text.body()).foregroundStyle(Theme.Palette.ink)
                }
                if item.mode == .info, let text = item.extractedText, !text.isEmpty {
                    Text(text)
                        .font(Theme.Text.list())
                        .foregroundStyle(Theme.Palette.ink(0.72))
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.Palette.live).frame(width: 2)
                        }
                }

                HStack(spacing: Theme.Space.s1) {
                    badge(item.mode == .info ? "Info kept" : "Image",
                          border: item.mode == .info ? Theme.Palette.live : Theme.Palette.rule,
                          fg: item.mode == .info ? Theme.Palette.live : Theme.Palette.ink(0.72))
                    if let due = item.dueDate {
                        Text(DueStatus.from(dueDate: due).label.uppercased())
                            .font(Theme.Text.meta()).foregroundStyle(Theme.Palette.live)
                    }
                    Spacer()
                    Text(item.createdAt, format: .relative(presentation: .named))
                        .font(Theme.Text.meta())
                        .foregroundStyle(Theme.Palette.ink(0.35))
                }
            }
            .padding(Theme.Space.s2)
        }
        .background(Theme.Palette.paper)
        .overlay(Rectangle().stroke(Theme.Palette.rule, lineWidth: 1))
    }

    private func badge(_ text: String, border: Color, fg: Color) -> some View {
        Text(text.uppercased()).font(Theme.Text.meta())
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(Rectangle().stroke(border, lineWidth: 1))
    }
}
