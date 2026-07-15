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
