import XCTest
@testable import ScreenshotKit

final class LogicTests: XCTestCase {

    private func item(daysAgo: Int, dueInDays: Int? = nil) -> SavedItem {
        let created = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let due = dueInDays.map { Calendar.current.date(byAdding: .day, value: $0, to: .now)! }
        return SavedItem(createdAt: created, mode: .info, extractedText: "x", dueDate: due)
    }

    func testTimeBucketsDropEmptyAndDedupe() {
        let items = [
            item(daysAgo: 1),   // yesterday
            item(daysAgo: 3),   // this week
            item(daysAgo: 40),  // last month
            item(daysAgo: 400), // last year
        ]
        let parts = TimeBucket.partition(items)
        let labels = parts.map { $0.bucket.label }
        // Only non-empty buckets present, in order.
        XCTAssertEqual(labels, ["Yesterday", "This week", "Last month", "Last year"])
        // No item appears in two buckets.
        let total = parts.reduce(0) { $0 + $1.items.count }
        XCTAssertEqual(total, items.count)
    }

    func testDueStatus() {
        XCTAssertEqual(DueStatus.from(dueDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!), .overdue(days: 1))
        XCTAssertEqual(DueStatus.from(dueDate: .now), .today)
        XCTAssertEqual(DueStatus.from(dueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)!), .soon(days: 2))
        XCTAssertEqual(DueStatus.from(dueDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!), .later(days: 10))
    }

    func testNeedingAttentionSorted() {
        let items = [
            item(daysAgo: 0, dueInDays: 2),   // soon
            item(daysAgo: 0, dueInDays: -1),  // overdue (most urgent)
            item(daysAgo: 0, dueInDays: 30),  // later — excluded
        ]
        let due = items.needingAttention()
        XCTAssertEqual(due.count, 2)
        // Most-overdue first.
        XCTAssertEqual(DueStatus.from(dueDate: due[0].dueDate!), .overdue(days: 1))
    }

    func testMultiCategoryRoundTrip() {
        let i = SavedItem(mode: .info, categories: [.todo, .kids])
        XCTAssertEqual(i.categories, [.todo, .kids])
        i.categories = [.shopping]
        XCTAssertEqual(i.categoryRaw, ["shopping"])
    }
}
