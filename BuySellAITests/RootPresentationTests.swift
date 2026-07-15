import XCTest

final class RootPresentationTests: XCTestCase {
    func testSplashDismissesAfterPromptDelayBeforeFirstLaunchTutorial() throws {
        let root = try appRouterSource()

        let splashDelayRange = try XCTUnwrap(root.range(of: "try? await Task.sleep(nanoseconds: 300_000_000)"))
        let dismissRange = try XCTUnwrap(root.range(of: "showSplash = false"))
        let tutorialGateRange = try XCTUnwrap(root.range(of: "if appStore.shouldShowTutorialOnLaunch"))
        let tutorialDelayRange = try XCTUnwrap(root.range(of: "try? await Task.sleep(nanoseconds: 240_000_000)"))
        let tutorialPresentationRange = try XCTUnwrap(root.range(of: "appStore.isShowingTutorial = true"))

        XCTAssertNotNil(root.range(of: "@State private var showSplash = true"))
        XCTAssertNotNil(root.range(of: "SplashView()\n                    .transition(.opacity)"))
        XCTAssertLessThan(splashDelayRange.lowerBound, dismissRange.lowerBound)
        XCTAssertLessThan(dismissRange.lowerBound, tutorialGateRange.lowerBound)
        XCTAssertLessThan(tutorialGateRange.lowerBound, tutorialDelayRange.lowerBound)
        XCTAssertLessThan(tutorialDelayRange.lowerBound, tutorialPresentationRange.lowerBound)
    }

    func testPromptSheetsUseSpecifiedDetentsDragIndicatorsAndCornerRadius() throws {
        let root = try appRouterSource()

        let snapResult = try sheetBlock(
            in: root,
            startingWith: #".sheet(item: $store.snapResultContext)"#,
            endingBefore: #".sheet(item: $store.marketplacePickerContext)"#
        )
        XCTAssertNotNil(snapResult.range(of: "SnapResultSheet(context: context)"))
        XCTAssertNotNil(snapResult.range(of: ".presentationDetents([.medium, .large])"))
        XCTAssertNotNil(snapResult.range(of: ".presentationDragIndicator(.visible)"))
        XCTAssertNotNil(snapResult.range(of: ".presentationCornerRadius(28)"))

        let marketplace = try sheetBlock(
            in: root,
            startingWith: #".sheet(item: $store.marketplacePickerContext)"#,
            endingBefore: #".sheet(item: $store.listingContext)"#
        )
        XCTAssertNotNil(marketplace.range(of: "MarketplacePickerSheet(context: context)"))
        XCTAssertNotNil(marketplace.range(of: ".presentationDetents([.large])"))
        XCTAssertNotNil(marketplace.range(of: ".presentationDragIndicator(.visible)"))
        XCTAssertNotNil(marketplace.range(of: ".presentationCornerRadius(28)"))

        let listing = try sheetBlock(
            in: root,
            startingWith: #".sheet(item: $store.listingContext)"#,
            endingBefore: #".overlay(alignment: .top)"#
        )
        XCTAssertNotNil(listing.range(of: "ListingSheet(context: context)"))
        XCTAssertNotNil(listing.range(of: ".presentationDetents([.large])"))
        XCTAssertNotNil(listing.range(of: ".presentationDragIndicator(.visible)"))
        XCTAssertNotNil(listing.range(of: ".presentationCornerRadius(28)"))
    }

    private func appRouterSource() throws -> String {
        try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
    }

    private func sheetBlock(in source: String, startingWith start: String, endingBefore end: String) throws -> String {
        let startRange = try XCTUnwrap(source.range(of: start))
        let endRange = try XCTUnwrap(source.range(of: end, range: startRange.upperBound..<source.endIndex))
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
