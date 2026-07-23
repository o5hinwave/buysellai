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

    func testStartupHistoryLoadUsesSwiftUITaskCancellation() throws {
        let root = try appRouterSource()

        let configureRange = try XCTUnwrap(root.range(of: ".task {\n            appStore.configure(modelContext: modelContext)"))
        let loadHistoryRange = try XCTUnwrap(root.range(of: "await appStore.loadHistory()"))
        let splashTaskRange = try XCTUnwrap(root.range(of: ".task {\n            try? await Task.sleep(nanoseconds: 300_000_000)"))

        XCTAssertLessThan(configureRange.lowerBound, loadHistoryRange.lowerBound)
        XCTAssertLessThan(loadHistoryRange.lowerBound, splashTaskRange.lowerBound)
        XCTAssertNil(root.range(of: "Task { @MainActor in\n                await appStore.loadHistory()"))
    }

    func testSellingFlowUsesCustomOverlayWithSpecifiedChrome() throws {
        let root = try appRouterSource()

        XCTAssertNotNil(root.range(of: "FlowSheetOverlay(context: flowSheetContext, reduceMotion: shouldReduceMotion)"))
        XCTAssertNotNil(root.range(of: "private struct FlowSheetOverlay"))
        XCTAssertNotNil(root.range(of: ".accessibilityHidden(appStore.flowSheetContext != nil)"))
        XCTAssertNotNil(root.range(of: "Color.brand.shadow.opacity(0.10)"))
        XCTAssertNotNil(root.range(of: "DragGesture(minimumDistance: 8)"))
        XCTAssertNotNil(root.range(of: ".nativeMaterialSheet(cornerRadius: 28, tintOpacity: 0.88, strokeOpacity: 0.68)"))
        XCTAssertNotNil(root.range(of: "appStore.dismissFlowSheet()"))
        XCTAssertNil(root.range(of: ".sheet(isPresented: flowSheetBinding)"))
        XCTAssertNil(root.range(of: ".background(Color.brand.background)\n        .clipShape(UnevenRoundedRectangle("))
        XCTAssertNil(root.range(of: #".sheet(item: $store.snapResultContext)"#))
        XCTAssertNil(root.range(of: #".sheet(item: $store.marketplacePickerContext)"#))
        XCTAssertNil(root.range(of: #".sheet(item: $store.listingContext)"#))

        let overlay = try sheetBlock(
            in: root,
            startingWith: #"private struct FlowSheetOverlay"#,
            endingBefore: #"struct SplashView"#
        )

        XCTAssertNotNil(overlay.range(of: "case .snapResult(let context):"))
        XCTAssertNotNil(overlay.range(of: "SnapResultSheet(context: context)"))
        XCTAssertNotNil(overlay.range(of: "case .marketplacePicker(let context):"))
        XCTAssertNotNil(overlay.range(of: "MarketplacePickerSheet(context: context)"))
        XCTAssertNotNil(overlay.range(of: "case .listing(let context):"))
        XCTAssertNotNil(overlay.range(of: "ListingSheet(context: context)"))
        XCTAssertNotNil(overlay.range(of: "proxy.size.height * 0.64"))
        XCTAssertNotNil(overlay.range(of: "mediumSheetHeight(in: proxy)"))
        XCTAssertNotNil(overlay.range(of: "largeSheetHeight(in: proxy)"))
        XCTAssertNotNil(overlay.range(of: ".accessibilityElement(children: .contain)"))
        XCTAssertNotNil(overlay.range(of: ".accessibilityAddTraits(.isModal)"))
        XCTAssertNotNil(overlay.range(of: ".accessibilityAction(.escape)"))
        XCTAssertNotNil(overlay.range(of: ".accessibilitySortPriority(1_000)"))
    }

    func testSellingFlowOverlayExposesAccessibleSheetIdentityAndDetentAdjustment() throws {
        let root = try appRouterSource()
        let overlay = try sheetBlock(
            in: root,
            startingWith: #"private struct FlowSheetOverlay"#,
            endingBefore: #"struct SplashView"#
        )

        XCTAssertNotNil(overlay.range(of: #".accessibilityHidden(true)"#))
        XCTAssertNotNil(overlay.range(of: #".accessibilityLabel(flowSheetAccessibilityLabel)"#))
        XCTAssertNotNil(overlay.range(of: #".accessibilityValue(flowSheetAccessibilityValue)"#))
        XCTAssertNotNil(overlay.range(of: #".accessibilityHint(flowSheetAccessibilityHint)"#))
        XCTAssertNotNil(overlay.range(of: #"Text("Item details".localized)"#))
        XCTAssertNotNil(overlay.range(of: #"Text("Marketplace choices".localized)"#))
        XCTAssertNotNil(overlay.range(of: #"Text("Listing draft".localized)"#))
        XCTAssertNotNil(overlay.range(of: #"Text("Half height".localized)"#))
        XCTAssertNotNil(overlay.range(of: #"Text("Expanded".localized)"#))
        XCTAssertNotNil(overlay.range(of: #"Text("Swipe up or down to resize. Escape closes the sheet.".localized)"#))
        XCTAssertNotNil(overlay.range(of: #"Text("Escape closes the sheet.".localized)"#))
        XCTAssertNotNil(overlay.range(of: #"FlowSheetAdjustableActionModifier(isEnabled: isSnapResultSheet)"#))
        XCTAssertNotNil(overlay.range(of: #"private func adjustSnapResultDetent(_ direction: AccessibilityAdjustmentDirection)"#))
        XCTAssertNotNil(overlay.range(of: #"case .increment:"#))
        XCTAssertNotNil(overlay.range(of: #"snapResultDetent = .large"#))
        XCTAssertNotNil(overlay.range(of: #"case .decrement:"#))
        XCTAssertNotNil(overlay.range(of: #"snapResultDetent = .medium"#))
        XCTAssertNotNil(overlay.range(of: #"content.accessibilityAdjustableAction(action)"#))
    }

    func testSnapResultFlowSheetSupportsMediumLargeDragDetents() throws {
        let root = try appRouterSource()
        let overlay = try sheetBlock(
            in: root,
            startingWith: #"private struct FlowSheetOverlay"#,
            endingBefore: #"struct SplashView"#
        )

        XCTAssertNotNil(root.range(of: "private enum FlowSheetDetent: Equatable"))
        XCTAssertNotNil(overlay.range(of: "@State private var snapResultDetent: FlowSheetDetent = .medium"))
        XCTAssertNotNil(overlay.range(of: ".animation(reduceMotion ? AppMotion.quick : AppMotion.sheet, value: snapResultDetent)"))
        XCTAssertNotNil(overlay.range(of: ".onChange(of: context) { _, newContext in"))
        XCTAssertNotNil(overlay.range(of: "snapResultDetent = .medium"))
        XCTAssertNotNil(overlay.range(of: "case .medium:\n                mediumSheetHeight(in: proxy)"))
        XCTAssertNotNil(overlay.range(of: "case .large:\n                largeSheetHeight(in: proxy)"))
        XCTAssertNotNil(overlay.range(of: "interactiveDragOffset(for: value.translation.height)"))
        XCTAssertNotNil(overlay.range(of: "shouldExpandSnapResult(for: value)"))
        XCTAssertNotNil(overlay.range(of: "shouldCollapseSnapResult(for: value)"))
        XCTAssertNotNil(overlay.range(of: "snapResultDetent = .large"))
        XCTAssertNotNil(overlay.range(of: "snapResultDetent = .medium"))
        XCTAssertNotNil(overlay.range(of: "translationHeight * 0.22"))
        XCTAssertNotNil(overlay.range(of: "value.translation.height < -72 || value.predictedEndTranslation.height < -132"))
        XCTAssertNotNil(overlay.range(of: "value.translation.height > 72 || value.predictedEndTranslation.height > 132"))
        XCTAssertNotNil(overlay.range(of: "value.translation.height > 220 || value.predictedEndTranslation.height > 320"))
    }

    func testSellingFlowAvoidsAccidentalBackdropTapDismissal() throws {
        let root = try appRouterSource()
        let overlay = try sheetBlock(
            in: root,
            startingWith: #"private struct FlowSheetOverlay"#,
            endingBefore: #"struct SplashView"#
        )

        XCTAssertNotNil(overlay.range(of: "DragGesture(minimumDistance: 8)"))
        XCTAssertNotNil(overlay.range(of: ".accessibilityAction(.escape)"))
        XCTAssertNotNil(overlay.range(of: "appStore.dismissFlowSheet()"))
        XCTAssertNil(overlay.range(of: ".onTapGesture"))
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
