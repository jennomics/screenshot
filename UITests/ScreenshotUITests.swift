import XCTest

/// Marketing-video demo flows (R6). Each test method drives one flow end to end;
/// the video pipeline's stage 2 wraps a single method in `xcrun simctl io
/// recordVideo`, so one method == one recorded clip.
///
/// Principles:
/// - Launch every flow with `-uiTestSeed` so the store is wiped and re-seeded to
///   identical state (R7) and no notification-permission dialog interrupts.
/// - Synchronize with element-existence waits, never bare sleeps (design). Dwell
///   is added *after* an element is confirmed present, purely so a human viewer
///   can read the screen — pacing, not synchronization.
final class ScreenshotUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: helpers

    private func launchedApp(captureEntry: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSeed"]
        // Only the capture flows (1 & 2) surface the in-app capture entry, so
        // the Home/Collections flows never show that button in their footage.
        if captureEntry { app.launchArguments.append("-uiCaptureEntry") }
        app.launch()
        return app
    }

    /// Wait for an element to exist, failing the test (and thus the capture) if
    /// it never appears. Returns the element for chaining.
    @discardableResult
    private func require(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 15) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing: \(label)")
        return element
    }

    /// Deliberate on-screen dwell so the recording is readable. Pacing only —
    /// the preceding `require` already handled synchronization.
    private func dwell(_ seconds: TimeInterval = 1.6) {
        Thread.sleep(forTimeInterval: seconds)
    }

    // MARK: Flow 1 — Capture modal (single continuous take)
    //
    // One recording that shows the whole capture modal: the seeded drivers-ed
    // screenshot, the category multi-select (Suggested -> Purpose), and the
    // due-date "Detected" banner — which are all visible in the same sheet. The
    // video renders this as ONE scene that zooms to the category chips (top of
    // the sheet) then pans down to the Detected banner (bottom), so the modal is
    // held open and stable long enough for the full combined voiceover + pan.

    func testFlow1_Capture() {
        let app = launchedApp(captureEntry: true)

        // Open the seeded capture modal (drivers-ed screenshot: To-do suggested,
        // Kids as an alternate — an errand *for your daughter*).
        require(app.buttons["open-capture-modal"], "capture entry").tap()
        require(app.staticTexts["SCREENSHOT"], "capture modal")
        require(app.staticTexts["SUGGESTED"], "suggested label")

        // Hold on the categories part first (top of the sheet). The video pans
        // here while the VO covers "keep the image… categorize… it's an errand".
        dwell(4.0)

        // Multi-select: add "Kids" → label flips Suggested -> Purpose, both
        // chips read selected.
        let kids = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Kids")).firstMatch
        require(kids, "Kids chip").tap()
        require(app.staticTexts["PURPOSE"], "purpose label after multi-select")
        dwell(3.0)

        // The DETECTED banner is already present lower in the same sheet; hold
        // the modal open, stable, while the video pans down to it for the
        // "if there's a date…" portion of the VO. No taps that would change or
        // dismiss the sheet — just keep it on screen and steady.
        require(app.staticTexts["✦ DETECTED"], "detected banner")
        dwell(7.0)
    }

    // MARK: Flow 2 — Home: "Needs attention" with urgency flags

    func testFlow2_NeedsAttention() {
        let app = launchedApp()

        // The redesigned Home opens delight-first: header, then the Most recent
        // highlight reel, then the quiet DUE OVER / DUE SOON summary (no scary
        // "NEEDS ATTENTION" heading). Let it settle on the top...
        require(app.staticTexts["Here's what caught your eye."], "home header")
        dwell(2.0)

        // ...then move down the page so the scene shows the flow of content
        // rather than sitting on one view. The due summary and Looking back come
        // into view as it scrolls.
        app.swipeUp(velocity: .slow)
        dwell(1.6)
        app.swipeUp(velocity: .slow)
        dwell(1.6)
        app.swipeUp(velocity: .slow)
        dwell(1.8)
    }

    // MARK: Flow 3 — Home: "Looking back" time buckets

    func testFlow3_LookingBack() {
        let app = launchedApp()

        require(app.staticTexts["Here's what caught your eye."], "home header")
        require(app.staticTexts["LOOKING BACK"], "looking back section")

        // Scroll down just far enough to reach the TOP time buckets (Yesterday
        // / This week / Last week) — these hold the image-bearing saves, so the
        // buckets show real pictures during the swaps. One controlled scroll,
        // then hold completely still so the once-a-second scroll-and-pause card
        // swaps are captured without competing scroll motion.
        app.swipeUp(velocity: .fast)
        dwell(0.6)
        // Rest on the buckets: ~9s of stillness -> several visible swaps.
        dwell(9.0)
    }

    // MARK: Flow 4 — Collections: masonry grid and a collection detail

    func testFlow4_Collections() {
        let app = launchedApp()

        require(app.staticTexts["Here's what caught your eye."], "home header")

        // Go straight to Collections and hold a long, STILL dwell on the masonry
        // grid — no scrolling that could transition away — so the recording has
        // a clean, several-second stretch of the grid (the shot we want to
        // feature). Grid-forward on purpose.
        require(app.tabBars.buttons["Collections"], "Collections tab").tap()
        dwell(7.0)

        // Then a brief look at a collection's detail (image + info-kept cards).
        let painting = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Painting")).firstMatch
        if painting.waitForExistence(timeout: 8) {
            painting.tap()
            dwell(3.0)
        } else {
            dwell(2.0)
        }
    }
}
