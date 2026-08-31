import XCTest
@testable import ScreenshotKit

final class AnalysisTests: XCTestCase {

    func testCategorySuggestionFromShoppingText() {
        let s = CategorySuggester.suggest(for: "Add to cart · $48 · free returns within 30 days")
        XCTAssertEqual(s.top, .shopping)
    }

    func testCategorySuggestionFromRecipeText() {
        let s = CategorySuggester.suggest(for: "Lemon orzo recipe · ingredients · preheat oven 425, 25 min")
        XCTAssertEqual(s.top, .recipes)
    }

    func testCategoryFallbackWhenNoMatch() {
        let s = CategorySuggester.suggest(for: "zzz qqq")
        XCTAssertEqual(s.top, .other)
        XCTAssertFalse(s.alternates.isEmpty)
    }

    func testDueDetectionRelativeWithinDays() {
        let due = DueDateDetector.detect(in: "Free returns within 30 days")
        XCTAssertNotNil(due)
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: due!.date).day
        XCTAssertEqual(days, 30)
    }

    func testDueDetectionTomorrow() {
        let due = DueDateDetector.detect(in: "Turn this in by tomorrow please")
        XCTAssertNotNil(due)
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: due!.date).day
        XCTAssertEqual(days, 1)
    }

    func testDueDetectionNoneWhenNoCue() {
        XCTAssertNil(DueDateDetector.detect(in: "a lovely muted terracotta palette"))
    }

    func testAnalyzeTextCombinesEverything() {
        let a = ScreenshotAnalyzer.analyze(text: "Order #4471 · return within 30 days")
        XCTAssertEqual(a.suggestion.top, .shopping)
        XCTAssertNotNil(a.due)
        XCTAssertFalse(a.extractedText.isEmpty)
    }
}
