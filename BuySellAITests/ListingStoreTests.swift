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

        secondContinuation?.resume(returning: "TITLE:\nFresh listing\n\nDESCRIPTION:\nReady to post.")
        await secondTask.value

        firstContinuation?.resume(returning: "TITLE:\nOld listing\n\nDESCRIPTION:\nOutdated copy.")
        await firstTask.value

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.listingText, "TITLE:\nFresh listing\n\nDESCRIPTION:\nReady to post.")
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

        secondContinuation?.resume(returning: "TITLE:\nFresh listing\n\nDESCRIPTION:\nReady to post.")
        await secondTask.value

        firstContinuation?.resume(throwing: APIError.timeout)
        await firstTask.value

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.listingText, "TITLE:\nFresh listing\n\nDESCRIPTION:\nReady to post.")
    }

    func testGenerateCancellationReturnsToIdleWithoutFailureCopy() async {
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in throw CancellationError() }
        )

        await store.generate(accessToken: nil)

        XCTAssertEqual(store.phase, .idle)
        XCTAssertEqual(store.listingText, "")
    }

    func testGenerateURLSessionCancellationReturnsToIdleWithoutFailureCopy() async {
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in throw URLError(.cancelled) }
        )

        await store.generate(accessToken: nil)

        XCTAssertEqual(store.phase, .idle)
        XCTAssertEqual(store.listingText, "")
    }

    func testGenerateTransportErrorUsesFriendlyOfflineCopy() async {
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in throw URLError(.notConnectedToInternet) }
        )

        await store.generate(accessToken: nil)

        XCTAssertEqual(store.phase, .failed(APIError.offline.localizedDescription))
    }

    func testListingFixtureCopyIsPolishedAndContractSafe() throws {
        let text = ListingFixtureText.sample(for: lamp)

        XCTAssertNoThrow(try ListingTextContract.validatedGenerated(text))
        XCTAssertTrue(text.contains("TITLE:\nLamp - Good"))
        XCTAssertTrue(text.contains("DESCRIPTION:\nLamp in good condition. Asking $45. See photos for details."))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("selling a"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("here's your listing"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("pickup or shipping depends"))
    }

    func testValidatedGeneratedListingReturnsTrimmedCopy() async {
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in
                "  \nTITLE:\nFresh listing\n\nDESCRIPTION:\nReady to post.\n  "
            }
        )

        await store.generate(accessToken: nil)

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.listingText, "TITLE:\nFresh listing\n\nDESCRIPTION:\nReady to post.")
    }

    func testExistingListingReturnsTrimmedCopyWhenReopened() {
        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: "  \nTITLE:\nStored listing\n\nDESCRIPTION:\nReady to post.\n  "
        )

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.listingText, "TITLE:\nStored listing\n\nDESCRIPTION:\nReady to post.")
    }

    func testUnsafeGeneratedOrExistingListingUsesFriendlyRetryCopy() async {
        for unsafeText in [
            "  \n\t  ",
            "TITLE:\nLamp",
            "Here's your listing:\nTITLE:\nLamp\n\nDESCRIPTION:\nReady.",
            "Sure, here's your listing:\nTITLE:\nLamp\n\nDESCRIPTION:\nReady.",
            "Draft listing:\nTITLE:\nLamp\n\nDESCRIPTION:\nReady.",
            "```text\nTITLE:\nLamp\n\nDESCRIPTION:\nReady.\n```",
            "TITLE:\nLamp\n\n```\n\nDESCRIPTION:\nReady."
        ] {
            let store = ListingStore(
                item: lamp,
                marketplace: .ebay,
                existingListingText: nil,
                generateHandler: { _, _, _ in unsafeText }
            )

            await store.generate(accessToken: nil)

            XCTAssertEqual(store.phase, .failed(APIError.decoding.localizedDescription))
            XCTAssertEqual(store.listingText, "")

            let reopenedStore = ListingStore(
                item: lamp,
                marketplace: .ebay,
                existingListingText: unsafeText
            )

            XCTAssertEqual(reopenedStore.phase, .failed(APIError.decoding.localizedDescription))
            XCTAssertEqual(reopenedStore.listingText, "")
        }
    }

    func testGeneratedListingRequiresTitleAndDescriptionBodies() async {
        for unsafeText in [
            "TITLE:\nLamp",
            "TITLE:\n\nDESCRIPTION:\nReady.",
            "TITLE:\n   \n\nDESCRIPTION:\nReady.",
            "TITLE:\nLamp\n\nDESCRIPTION:\n",
            "TITLE:\nLamp\n\nDESCRIPTION:\n   "
        ] {
            let store = ListingStore(
                item: lamp,
                marketplace: .ebay,
                existingListingText: nil,
                generateHandler: { _, _, _ in unsafeText }
            )

            await store.generate(accessToken: nil)

            XCTAssertEqual(store.phase, .failed(APIError.decoding.localizedDescription))
            XCTAssertEqual(store.listingText, "")
        }
    }

    func testGenerateUnknownErrorDoesNotExposeRawDescription() async {
        struct RawBackendError: LocalizedError {
            var errorDescription: String? {
                "NSURLErrorDomain Code=-1009 raw listing detail"
            }
        }

        let store = ListingStore(
            item: lamp,
            marketplace: .ebay,
            existingListingText: nil,
            generateHandler: { _, _, _ in throw RawBackendError() }
        )

        await store.generate(accessToken: nil)

        XCTAssertEqual(store.phase, .failed(APIError.unknown.localizedDescription))
        if case .failed(let message) = store.phase {
            XCTAssertFalse(message.contains("NSURLErrorDomain"))
            XCTAssertFalse(message.contains("raw listing detail"))
        }
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
