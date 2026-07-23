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

    func testCommitEditsRestoresInvalidNameAndPriceTextToLastValidValues() {
        let store = SnapResultStore(imageData: Data())
        store.item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        store.nameText = "  \n\t  "
        store.priceText = "0"

        store.commitEdits()

        XCTAssertEqual(store.item?.name, "Lamp")
        XCTAssertEqual(store.item?.priceEstimate, Decimal(45))
        XCTAssertEqual(store.nameText, "Lamp")
        XCTAssertEqual(store.priceText, "45")

        store.priceText = "not a price"
        store.commitEdits()

        XCTAssertEqual(store.item?.priceEstimate, Decimal(45))
        XCTAssertEqual(store.priceText, "45")
    }

    func testCommitEditsRoundsSubDollarPriceUpToMinimumListingPrice() {
        let store = SnapResultStore(imageData: Data())
        store.item = DetectedItem(
            name: "Sticker",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(2)
        )
        store.nameText = "Sticker"
        store.priceText = "0.49"

        store.commitEdits(priceLocale: Locale(identifier: "en_US"))

        XCTAssertEqual(store.item?.priceEstimate, Decimal(1))
        XCTAssertEqual(store.priceText, "1")
    }

    func testCycleActionsCommitTextEditsAndReplaceDetectedItemSafely() {
        let store = SnapResultStore(imageData: Data())
        store.item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        store.nameText = "  Brass lamp  "
        store.priceText = "$52.40"

        store.cycleCategory()

        XCTAssertEqual(store.item?.name, "Brass lamp")
        XCTAssertEqual(store.item?.priceEstimate, Decimal(52))
        XCTAssertEqual(store.item?.category, .tools)
        XCTAssertEqual(store.item?.condition, .good)

        store.cycleCondition()

        XCTAssertEqual(store.item?.condition, .fair)
        XCTAssertEqual(store.item?.category, .tools)
    }

    func testSelectionActionsCommitTextEditsAndApplyExactValues() {
        let store = SnapResultStore(imageData: Data())
        store.item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        store.nameText = "  Brass lamp  "
        store.priceText = "$52.40"

        store.selectCategory(.art)

        XCTAssertEqual(store.item?.name, "Brass lamp")
        XCTAssertEqual(store.item?.priceEstimate, Decimal(52))
        XCTAssertEqual(store.item?.category, .art)
        XCTAssertEqual(store.item?.condition, .good)

        store.selectCondition(.likeNew)

        XCTAssertEqual(store.item?.condition, .likeNew)
        XCTAssertEqual(store.item?.category, .art)
    }

    func testCycleActionsDoNotUseOptionalChainedObservedMutation() throws {
        let source = try String(
            contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultStore.swift"),
            encoding: .utf8
        )

        XCTAssertNil(source.range(of: "item?.category ="))
        XCTAssertNil(source.range(of: "item?.condition ="))
        XCTAssertNotNil(source.range(of: "guard var edited = item else { return }"))
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

    func testAnalyzeRoundsSubDollarPriceUpToMinimumListingPrice() async throws {
        let subDollarPrice = try XCTUnwrap(Decimal(string: "0.49", locale: Locale(identifier: "en_US_POSIX")))
        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in
                AnalyzeResponse(name: "Sticker", category: "Home", condition: "good", currentPrice: subDollarPrice)
            }
        )

        await store.analyze(accessToken: nil)

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.item?.priceEstimate, Decimal(1))
        XCTAssertEqual(store.priceText, "1")
    }

    func testAnalyzeStoresOnePlainGuidanceHintWhenAvailable() async {
        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in
                AnalyzeResponse(
                    name: "Lamp",
                    category: "Home",
                    condition: "good",
                    currentPrice: Decimal(45),
                    analysis: AnalyzeIntelligence(
                        itemFacts: [AnalyzeItemFact(label: "Material", value: "Brass", confidence: 0.8)],
                        missingFacts: ["maker"],
                        photoPrompt: "Show the maker mark."
                    )
                )
            }
        )

        await store.analyze(accessToken: nil)

        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(store.analysisDetails?.itemFacts.first?.label, "Material")
        XCTAssertEqual(store.analysisDetails?.itemFacts.first?.value, "Brass")
        XCTAssertEqual(store.analysisDetails?.itemFacts.first?.confidence, 0.8)
        XCTAssertEqual(store.analysisDetails?.missingFacts, ["maker"])
        XCTAssertEqual(store.analysisGuidance, "Show the maker mark.")
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

    func testStillWorkingTimerIsOwnedAndCancelledAtTerminalStates() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultStore.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "private var stillWorkingTask: Task<Void, Never>?"))
        XCTAssertNotNil(source.range(of: "stillWorkingTask = Task { @MainActor in"))
        XCTAssertNotNil(source.range(of: "guard Task.isCancelled == false else { return }"))
        XCTAssertNotNil(source.range(of: "private func cancelStillWorkingTask()"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "cancelStillWorkingTask()").count - 1, 4)
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

    func testAnalyzeCancellationReturnsToIdleWithoutFailureCopy() async {
        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in throw CancellationError() }
        )

        await store.analyze(accessToken: nil)

        XCTAssertEqual(store.phase, .idle)
        XCTAssertFalse(store.showStillWorking)
        XCTAssertNil(store.item)
    }

    func testAnalyzeURLSessionCancellationReturnsToIdleWithoutFailureCopy() async {
        let store = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in throw URLError(.cancelled) }
        )

        await store.analyze(accessToken: nil)

        XCTAssertEqual(store.phase, .idle)
        XCTAssertFalse(store.showStillWorking)
        XCTAssertNil(store.item)
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
        XCTAssertNil(invalidStore.analysisDetails)

        let freeStore = SnapResultStore(
            imageData: Data(),
            analyzeHandler: { _, _ in
                AnalyzeResponse(name: "Lamp", category: "Home", condition: "good", currentPrice: Decimal(0))
            }
        )

        await freeStore.analyze(accessToken: nil)

        XCTAssertEqual(freeStore.phase, .failed(APIError.decoding.localizedDescription))
        XCTAssertNil(freeStore.item)
        XCTAssertNil(freeStore.analysisDetails)
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

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
