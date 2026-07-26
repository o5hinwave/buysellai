import XCTest
@testable import BuySellAI

final class ProductAnalyticsTests: XCTestCase {
    func testEarlyAccessProductEventCatalogCoversRequiredMetrics() {
        let events = Set(ProductAnalyticsEvent.allCases.map(\.rawValue))

        XCTAssertTrue(events.isSuperset(of: [
            "app_opened",
            "photo_captured",
            "identification_completed",
            "identification_corrected",
            "follow_up_question_answered",
            "follow_up_questions_completed",
            "grounded_research_started",
            "grounded_research_completed",
            "marketplace_selected",
            "listing_generated",
            "listing_copied_or_exported",
            "item_saved",
            "user_created_second_listing",
            "user_returned_after_1_day",
            "user_returned_after_7_days",
            "user_returned_after_30_days",
            "rate_limit_reached"
        ]))
    }

    func testAnalyticsPayloadKeepsOnlyCoarseSafeValues() {
        let payload = ProductAnalytics.sanitizedPayload([
            "Marketplace": "facebook marketplace",
            "email": "person@example.com",
            "item_name": "Grandma's private lamp",
            "listing_title": "Signed private collectible",
            "photo_url": "https://example.com/private-photo.jpg",
            "source_url": "https://example.com/sold-comp",
            "serial_number": "ABC123PRIVATE",
            "pickup_address": "123 private road",
            "grounded_search_count": "3",
            "estimated_ai_cost_cents": "0.18",
            "image_bytes_bucket": "1mb_3mb",
            "photo_scope": "recommended",
            "bad key!": "value with spaces & symbols"
        ])

        XCTAssertTrue(payload.contains("marketplace=facebook_marketplace"))
        XCTAssertTrue(payload.contains("grounded_search_count=3"))
        XCTAssertTrue(payload.contains("estimated_ai_cost_cents=0.18"))
        XCTAssertTrue(payload.contains("image_bytes_bucket=1mb_3mb"))
        XCTAssertTrue(payload.contains("photo_scope=recommended"))
        XCTAssertTrue(payload.contains("badkey=value_with_spaces__symbols"))
        XCTAssertFalse(payload.contains("email="))
        XCTAssertFalse(payload.contains("item_name="))
        XCTAssertFalse(payload.contains("listing_title="))
        XCTAssertFalse(payload.contains("photo_url="))
        XCTAssertFalse(payload.contains("source_url="))
        XCTAssertFalse(payload.contains("serial_number="))
        XCTAssertFalse(payload.contains("pickup_address="))
        XCTAssertFalse(payload.contains("private"))
        XCTAssertFalse(payload.contains("@"))
        XCTAssertFalse(payload.contains("'"))
    }

    func testAppOpenedRecordsReturnBucketsWithoutCrashing() {
        let suiteName = "ProductAnalyticsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstOpen = Date(timeIntervalSince1970: 1_000)
        ProductAnalytics.recordAppOpened(defaults: defaults, now: firstOpen)
        ProductAnalytics.recordAppOpened(defaults: defaults, now: firstOpen.addingTimeInterval(86_400))
        ProductAnalytics.recordAppOpened(defaults: defaults, now: firstOpen.addingTimeInterval(7 * 86_400))
        ProductAnalytics.recordAppOpened(defaults: defaults, now: firstOpen.addingTimeInterval(30 * 86_400))

        XCTAssertNotNil(defaults.object(forKey: "BuySell.analytics.lastOpenDate"))
        XCTAssertNotNil(defaults.object(forKey: "BuySell.analytics.firstOpenDate"))
        XCTAssertTrue(defaults.bool(forKey: "BuySell.analytics.returnedAfter1Day"))
        XCTAssertTrue(defaults.bool(forKey: "BuySell.analytics.returnedAfter7Days"))
        XCTAssertTrue(defaults.bool(forKey: "BuySell.analytics.returnedAfter30Days"))
    }

    func testAppOpenedReturnMilestonesUseFirstOpenNotPreviousOpen() {
        let suiteName = "ProductAnalyticsFirstOpenTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstOpen = Date(timeIntervalSince1970: 10_000)
        ProductAnalytics.recordAppOpened(defaults: defaults, now: firstOpen)

        for day in 1...30 {
            ProductAnalytics.recordAppOpened(defaults: defaults, now: firstOpen.addingTimeInterval(Double(day) * 86_400))
        }

        XCTAssertEqual(defaults.object(forKey: "BuySell.analytics.firstOpenDate") as? Date, firstOpen)
        XCTAssertTrue(defaults.bool(forKey: "BuySell.analytics.returnedAfter1Day"))
        XCTAssertTrue(defaults.bool(forKey: "BuySell.analytics.returnedAfter7Days"))
        XCTAssertTrue(defaults.bool(forKey: "BuySell.analytics.returnedAfter30Days"))
    }
}
