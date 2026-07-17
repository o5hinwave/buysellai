import XCTest
@testable import BuySellAI

@MainActor
final class SnapResultStoreTests: XCTestCase {
    func testCommitEditsTrimsNameAndNormalizesPrice() {
        let store = SnapResultStore(imageData: Data())
        store.item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        store.nameText = "  Brass lamp  "
        store.priceText = " $52.40 "

        store.commitEdits()

        XCTAssertEqual(store.item?.name, "Brass lamp")
        XCTAssertEqual(store.item?.priceEstimate, Decimal(52))
        XCTAssertEqual(store.priceText, "52")
    }

    func testCommitEditsParsesLocalizedCommaDecimalPrice() {
        let store = SnapResultStore(imageData: Data())
        store.item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        store.nameText = "Lamp"
        store.priceText = "45,50"

        store.commitEdits(priceLocale: Locale(identifier: "fr_FR"))

        XCTAssertEqual(store.item?.priceEstimate, Decimal(46))
        XCTAssertEqual(store.priceText, "46")
    }

    func testPriceParserHandlesCurrencySymbolsAndGrouping() throws {
        XCTAssertEqual(
            SnapResultStore.priceDecimal(from: "$1,234.50", locale: Locale(identifier: "en_US")),
            try XCTUnwrap(Decimal(string: "1234.5", locale: Locale(identifier: "en_US_POSIX")))
        )
        XCTAssertEqual(
            SnapResultStore.priceDecimal(from: "1 234,50 €", locale: Locale(identifier: "fr_FR")),
            try XCTUnwrap(Decimal(string: "1234.5", locale: Locale(identifier: "en_US_POSIX")))
        )
    }

    func testStillWorkingHintAppearsOnlyAfterDelayDuringLoading() async {
        let store = SnapResultStore(
            imageData: Data(),
            stillWorkingDelayNanoseconds: 80_000_000,
            analyzeHandler: { _, _ in
                try await Task.sleep(nanoseconds: 180_000_000)
                return AnalyzeResponse(name: "Lamp", category: "Home", condition: "good", currentPrice: Decimal(45))
            }
        )

        let analysisTask = Task { await store.analyze(accessToken: nil) }
        XCTAssertFalse(store.showStillWorking)

        try? await Task.sleep(nanoseconds: 110_000_000)

        XCTAssertTrue(store.showStillWorking)
        await analysisTask.value
        XCTAssertEqual(store.phase, .success)
    }

    func testStaleStillWorkingHintDoesNotLeakIntoRetriedAnalysis() async {
        var attempts = 0
        let store = SnapResultStore(
            imageData: Data(),
            stillWorkingDelayNanoseconds: 200_000_000,
            analyzeHandler: { _, _ in
                attempts += 1
                if attempts == 1 {
                    throw APIError.timeout
                }
                try await Task.sleep(nanoseconds: 420_000_000)
                return AnalyzeResponse(name: "Lamp", category: "Home", condition: "good", currentPrice: Decimal(45))
            }
        )

        await store.analyze(accessToken: nil)
        XCTAssertEqual(store.phase, .failed(APIError.timeout.localizedDescription))

        try? await Task.sleep(nanoseconds: 100_000_000)

        let retryTask = Task { await store.analyze(accessToken: nil) }
        try? await Task.sleep(nanoseconds: 130_000_000)

        XCTAssertEqual(store.phase, .loading)
        XCTAssertFalse(store.showStillWorking)

        try? await Task.sleep(nanoseconds: 110_000_000)

        XCTAssertTrue(store.showStillWorking)
        await retryTask.value
        XCTAssertEqual(store.phase, .success)
    }

    func testStaleAnalyzeSuccessDoesNotOverrideLatestRetry() async {
        var attempts = 0
        var firstContinuation: CheckedContinuation<AnalyzeResponse, Error>?
        var secondContinuation: CheckedContinuation<AnalyzeResponse, Error>?
        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in
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

        let firstTask = Task { await store.analyze(accessToken: nil) }
        await waitUntil { firstContinuation != nil }
        let secondTask = Task { await store.analyze(accessToken: nil) }
        await waitUntil { secondContinuation != nil }

        secondContinuation?.resume(returning: AnalyzeResponse(name: "Fresh lamp", category: "Home", condition: "good", currentPrice: Decimal(45)))
        await secondTask.value

        firstContinuation?.resume(returning: AnalyzeResponse(name: "Old chair", category: "Furniture", condition: "fair", currentPrice: Decimal(12)))
        await firstTask.value

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.item?.name, "Fresh lamp")
        XCTAssertEqual(store.nameText, "Fresh lamp")
        XCTAssertEqual(store.priceText, "45")
    }

    func testAnalyzeCancellationUsesFriendlyRetryCopy() async {
        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in throw CancellationError() }
        )

        await store.analyze(accessToken: nil)

        XCTAssertEqual(store.phase, .failed(APIError.unknown.localizedDescription))
    }

    func testAnalyzeTransportErrorUsesFriendlyOfflineCopy() async {
        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in throw URLError(.notConnectedToInternet) }
        )

        await store.analyze(accessToken: nil)

        XCTAssertEqual(store.phase, .failed(APIError.offline.localizedDescription))

        let invalidStore = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in
                AnalyzeResponse(name: "  \n\t  ", category: "Home", condition: "good", currentPrice: Decimal(45))
            }
        )

        await invalidStore.analyze(accessToken: nil)

        XCTAssertEqual(invalidStore.phase, .failed(APIError.decoding.localizedDescription))
        XCTAssertNil(invalidStore.item)

        let freeStore = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in
                AnalyzeResponse(name: "Lamp", category: "Home", condition: "good", currentPrice: Decimal(0))
            }
        )

        await freeStore.analyze(accessToken: nil)

        XCTAssertEqual(freeStore.phase, .failed(APIError.decoding.localizedDescription))
        XCTAssertNil(freeStore.item)
    }

    func testAnalyzeUnknownErrorDoesNotExposeRawDescription() async {
        struct RawBackendError: LocalizedError {
            var errorDescription: String? {
                "NSURLErrorDomain Code=-1009 raw backend detail"
            }
        }

        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in throw RawBackendError() }
        )

        await store.analyze(accessToken: nil)

        XCTAssertEqual(store.phase, .failed(APIError.unknown.localizedDescription))
        if case .failed(let message) = store.phase {
            XCTAssertFalse(message.contains("NSURLErrorDomain"))
            XCTAssertFalse(message.contains("raw backend detail"))
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
