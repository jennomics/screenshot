#if DEBUG
import SwiftUI
import UIKit
import ScreenshotKit

/// DEBUG-only, `-uiTestSeed`-gated entry point that presents the real
/// `CaptureModalView` inside the app so the marketing-video UI tests can record
/// the capture flow (R6 flows 1-2) as genuine simulator UI (V4).
///
/// Production capture happens in the Share Extension via the iOS share sheet,
/// which XCUITest cannot drive from a clean app launch. Rather than fake the
/// modal in Remotion, this presents the same ScreenshotKit view with injected,
/// deterministic analysis so nothing depends on live on-device inference (C4).
/// It never ships: the whole file is `#if DEBUG`, and the trigger only appears
/// when the app is launched with `-uiTestSeed`.
///
/// Usage: attach `.debugCaptureEntry()` to a root view. When the launch
/// argument is present it overlays a single control (accessibility id
/// `open-capture-modal`) the test taps to open the modal.
struct DebugCaptureEntry: ViewModifier {
    @State private var showModal = false

    // The capture entry is only shown for the capture flows (1 & 2), gated on a
    // dedicated argument so the Home/Collections flows (3/4/5) never show the
    // button in their footage. `-uiTestSeed` still controls the deterministic
    // seed; `-uiCaptureEntry` controls this entry point specifically.
    private var enabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiCaptureEntry")
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if enabled {
                    Button {
                        showModal = true
                    } label: {
                        Text("Capture a screenshot")
                            .font(Theme.Text.list())
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Theme.Palette.live)
                            .padding(Theme.Space.s2)
                    }
                    .accessibilityIdentifier("open-capture-modal")
                }
            }
            .fullScreenCover(isPresented: $showModal) {
                CaptureModalView(
                    image: Self.seedImage,
                    seed: Self.seedAnalysis,
                    onComplete: { showModal = false },
                    onCancel: { showModal = false }
                )
                .background(BackgroundClearView())
            }
    }

    // A real seed screenshot so the modal preview shows genuine content.
    private static var seedImage: UIImage? {
        guard let url = Bundle.main.url(forResource: "drivers-ed", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // Deterministic analysis matching the drivers-ed screenshot: a "To-do"
    // suggestion with a "Kids" alternate (so tapping the alternate flips the
    // label Suggested -> Purpose), and a detected deadline for the "Detected"
    // banner + preset chips. No Vision, fully reproducible.
    private static var seedAnalysis: ScreenshotAnalysis {
        ScreenshotAnalysis(
            extractedText: "Riverside Driving School · enrollment closes Fri · $480 · (555) 0142",
            suggestion: .init(top: .todo, alternates: [.kids, .shopping]),
            due: DetectedDueDate(
                date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
                phrase: "enrollment closes Fri"
            )
        )
    }
}

/// Makes the fullScreenCover host transparent so the modal's own dimmed
/// backdrop reads correctly instead of an opaque system background.
private struct BackgroundClearView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        DispatchQueue.main.async { v.superview?.superview?.backgroundColor = .clear }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    func debugCaptureEntry() -> some View { modifier(DebugCaptureEntry()) }
}
#endif
