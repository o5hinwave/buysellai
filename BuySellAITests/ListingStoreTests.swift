import XCTest
@testable import BuySellAI

@MainActor
final class ListingStoreTests: XCTestCase {
    private var lamp: DetectedItem {
        DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
    }

    func testStaleGeneratedListingDoesNotOverrideLatestRegeneration() async {
        var attempts = 0
        var firstContinuation: CheckedContinuation<String, Error>?
        var secondContinuation: CheckedContinuation<String, Error>?
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in
                attempts += 1
                return try await withCheckedThrowingContinuation { continuation in
                    if attempts == 1 {
                        firstContinuation = continuation
                    } else {
                        secondContinuation = continuation
                    }
                }
            }
        )

        let firstTask = Task { await store.generate(accessToken: nil) }
        await waitUntil { firstContinuation != nil }
        let secondTask = Task { await store.generate(accessToken: nil) }
        await waitUntil { secondContinuation != nil }

        secondContinuation?.resume(returning: "Fresh listing")
        await secondTask.value

        firstContinuation?.resume(returning: "Old listing")
        await firstTask.value

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.listingText, "Fresh listing")
    }

    func testStaleGenerateFailureDoesNotOverrideLatestSuccess() async {
        var attempts = 0
        var firstContinuation: CheckedContinuation<String, Error>?
        var secondContinuation: CheckedContinuation<String, Error>?
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in
                attempts += 1
                return try await withCheckedThrowingContinuation { continuation in
                    if attempts == 1 {
                        firstContinuation = continuation
                    } else {
                        secondContinuation = continuation
                    }
                }
            }
        )

        let firstTask = Task { await store.generate(accessToken: nil) }
        await waitUntil { firstContinuation != nil }
        let secondTask = Task { await store.generate(accessToken: nil) }
        await waitUntil { secondContinuation != nil }

        secondContinuation?.resume(returning: "Fresh listing")
        await secondTask.value

        firstContinuation?.resume(throwing: APIError.timeout)
        await firstTask.value

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.listingText, "Fresh listing")
    }

    func testGenerateCancellationUsesFriendlyRetryCopy() async {
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in throw CancellationError() }
        )

        await store.generate(accessToken: nil)

        XCTAssertEqual(store.phase, .failed(APIError.unknown.localizedDescription))
    }

    private func waitUntil(
        _ condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(1)
        while condition() == false, Date() < deadline {
            await Task.yield()
        }
        XCTAssertTrue(condition(), file: file, line: line)
    }
}
