import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// `Category` here is ScreenshotKit's own model type. (In the Share Extension
// this file needed a typealias to disambiguate from the ObjC runtime's
// `Category`; inside the module the model type is unambiguous.)

/// The capture modal — the moment a screenshot is saved. Mirrors the prototype:
/// multi-select categories (Suggested → Purpose), free-text note, auto-detected
/// due date, reminder, and the two-way "Save info" / "Save image" choice.
/// Dismiss is explicit only (X + Cancel).
///
/// Lives in ScreenshotKit so both the Share Extension (its production entry via
/// the iOS share sheet) and the app (a DEBUG-only, seeded entry used by the
/// marketing-video UI tests) can present the same real UI.
///
/// When `seed` is supplied the modal skips live Vision analysis and renders the
/// injected, deterministic values — this is what lets the video pipeline show
/// flows 1 and 2 as real UI without relying on on-device inference (C4). When
/// `seed` is nil the behavior is unchanged: OCR the image and analyze live.
public struct CaptureModalView: View {
    @Environment(\.modelContext) private var context

    let image: UIImage?
    let seed: ScreenshotAnalysis?
    let onComplete: () -> Void
    let onCancel: () -> Void

    // Working state
    @State private var chosen: Set<Category> = [.other]
    @State private var suggestion: Category = .other
    @State private var alts: [Category] = []
    @State private var note: String = ""
    @State private var dueInDays: Int?
    @State private var detectedPhrase: String?
    @State private var extractedText: String = ""
    @State private var analyzing = true

    public init(
        image: UIImage?,
        seed: ScreenshotAnalysis? = nil,
        onComplete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.image = image
        self.seed = seed
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    private var isPristine: Bool { chosen == [suggestion] }
    private var categoryLabel: String { isPristine ? "Suggested" : "Purpose" }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55).ignoresSafeArea()
            sheet
        }
        .task { await analyze() }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            HStack {
                Text("SCREENSHOT").font(Theme.Text.meta()).foregroundStyle(Theme.Palette.ink(0.5))
                Spacer()
                Button(action: onCancel) { Text("✕").font(Theme.Text.h3()) }
                    .foregroundStyle(Theme.Palette.ink)
            }

            preview

            Text("Why are you saving this?")
                .font(Theme.Text.h3()).foregroundStyle(Theme.Palette.ink)

            label(analyzing ? "Reading screenshot…" : categoryLabel)
            chips([suggestion] + alts) { cat in
                Text((chosen.contains(cat) ? "✓ " : "") + cat.displayName)
            } action: { toggle($0) } selected: { chosen.contains($0) }

            TextField("Or say it in your own words…", text: $note, axis: .vertical)
                .font(Theme.Text.body())
                .padding(12)
                .overlay(Rectangle().stroke(Theme.Palette.rule, lineWidth: 1))

            dueSection

            HStack(spacing: Theme.Space.s1) {
                saveButton(title: "Save info", mode: .info, fill: Theme.Palette.live)
                saveButton(title: "Save image", mode: .image, fill: Theme.Palette.ink)
            }

            Button("Taken by mistake? Cancel", action: onCancel)
                .font(Theme.Text.meta()).foregroundStyle(Theme.Palette.ink(0.35))
                .frame(maxWidth: .infinity)
        }
        .padding(Theme.Space.s3)
        .background(Theme.Palette.paper)
        .overlay(Rectangle().stroke(Theme.Palette.ink, lineWidth: 2).ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder private var preview: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(height: 150).clipped()
                .overlay(Rectangle().stroke(Theme.Palette.rule, lineWidth: 1))
        } else {
            Rectangle().fill(Theme.Palette.rule).frame(height: 150)
        }
    }

    @ViewBuilder private var dueSection: some View {
        label(detectedPhrase == nil ? "Add a due date" : "Due date")
        if let phrase = detectedPhrase {
            HStack {
                Text("✦ DETECTED").font(Theme.Text.meta()).foregroundStyle(Theme.Palette.live)
                Text("\"\(phrase)\"").font(Theme.Text.list()).italic()
                    .foregroundStyle(Theme.Palette.ink(0.72))
            }
            .padding(8).background(Theme.Palette.liveWash)
        }
        let presets: [(String, Int?)] = [("Today", 0), ("Tomorrow", 1), ("In 3 days", 3), ("In a week", 7), ("No date", nil)]
        HStack(spacing: Theme.Space.s1) {
            ForEach(presets, id: \.0) { p in
                Button(p.0) { dueInDays = p.1 }
                    .font(Theme.Text.meta())
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .foregroundStyle(dueInDays == p.1 ? Theme.Palette.paper : Theme.Palette.ink(0.72))
                    .background(dueInDays == p.1 ? Theme.Palette.ink : Theme.Palette.paper)
                    .overlay(Rectangle().stroke(Theme.Palette.rule, lineWidth: 1))
            }
        }
    }

    // MARK: pieces

    private func label(_ t: String) -> some View {
        Text(t.uppercased()).font(Theme.Text.meta()).foregroundStyle(Theme.Palette.ink(0.5))
    }

    private func chips<L: View>(
        _ cats: [Category],
        @ViewBuilder label: @escaping (Category) -> L,
        action: @escaping (Category) -> Void,
        selected: @escaping (Category) -> Bool
    ) -> some View {
        HStack(spacing: Theme.Space.s1) {
            ForEach(cats) { cat in
                Button { action(cat) } label: { label(cat).font(Theme.Text.meta()) }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .foregroundStyle(selected(cat) ? Theme.Palette.paper : Theme.Palette.ink(0.72))
                    .background(selected(cat) ? Theme.Palette.ink : Theme.Palette.paper)
                    .overlay(Rectangle().stroke(Theme.Palette.rule, lineWidth: 1))
            }
        }
    }

    private func saveButton(title: String, mode: SaveMode, fill: Color) -> some View {
        Button { save(mode: mode) } label: {
            Text(title).font(Theme.Text.list())
                .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .background(fill)
    }

    // MARK: actions

    private func toggle(_ cat: Category) {
        if chosen.contains(cat) { if chosen.count > 1 { chosen.remove(cat) } }
        else { chosen.insert(cat) }
    }

    /// Real on-device analysis: OCR the screenshot with Vision, then derive the
    /// category suggestion and due date from the extracted text. All local.
    /// When a deterministic `seed` was injected (video UI tests), use it and
    /// skip Vision entirely.
    private func analyze() async {
        let analysis: ScreenshotAnalysis
        if let seed {
            analysis = seed
        } else if let cg = image?.cgImage {
            analysis = await ScreenshotAnalyzer.analyze(image: cg)
        } else {
            analysis = ScreenshotAnalyzer.analyze(text: "")
        }

        await MainActor.run {
            extractedText = analysis.extractedText
            suggestion = analysis.suggestion.top
            alts = analysis.suggestion.alternates
            chosen = [analysis.suggestion.top]
            if let due = analysis.due {
                detectedPhrase = due.phrase
                dueInDays = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: .now),
                    to: Calendar.current.startOfDay(for: due.date)
                ).day
            }
            analyzing = false
        }
    }

    private func save(mode: SaveMode) {
        let due = dueInDays.map { Calendar.current.date(byAdding: .day, value: $0, to: .now)! }

        // If there's a due date, build a reminder (9am on the due day) with an
        // implied expiry so the item can auto-fade after it passes.
        var reminder: ReminderPlan?
        if let due {
            let fire = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
            let expiry = Calendar.current.date(byAdding: .day, value: 2, to: due)
            reminder = ReminderPlan(fireDate: fire, expiresAt: expiry)
        }

        let item = SavedItem(
            mode: mode,
            note: note.isEmpty ? nil : note,
            extractedText: mode == .info ? extractedText : nil,
            imageData: mode == .image ? image?.pngData() : nil,
            sourceApp: nil,
            categories: Array(chosen),
            dueDate: due,
            dueSourcePhrase: detectedPhrase,
            reminder: reminder
        )
        context.insert(item)
        try? context.save()

        // Extract a Sendable reminder snapshot synchronously (on this view's
        // actor) BEFORE crossing into the Task — never capture the SavedItem or
        // ModelContext in a concurrent closure.
        if let req = NotificationScheduler.request(for: item) {
            Task { await NotificationScheduler.schedule(req) }
        }
        onComplete()
    }
}
