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

    func testSellingFlowUsesNativeSheetWithSystemChrome() throws {
        let root = try appRouterSource()

        XCTAssertNotNil(root.range(of: #".sheet(isPresented: flowSheetBinding)"#))
        XCTAssertNotNil(root.range(of: "FlowSheetContent()"))
        XCTAssertNotNil(root.range(of: ".nativeSystemFlowSheetPresentationChrome("))
        XCTAssertNotNil(root.range(of: "detents: flowSheetDetents"))
        XCTAssertNotNil(root.range(of: "private struct FlowSheetContent: View"))
        XCTAssertNotNil(root.range(of: ".accessibilityHidden(appStore.flowSheetContext != nil)"))
        XCTAssertNotNil(root.range(of: "appStore.dismissFlowSheet()"))
        XCTAssertNil(root.range(of: "private struct FlowSheetOverlay"))
        XCTAssertNil(root.range(of: "Color.brand.shadow.opacity(0.10)"))
        XCTAssertNil(root.range(of: "DragGesture(minimumDistance: 8)"))
        XCTAssertNil(root.range(of: ".nativeMaterialSheet(cornerRadius: 28, tintOpacity: 0.88, strokeOpacity: 0.68)"))
        XCTAssertNil(root.range(of: ".background(Color.brand.background)\n        .clipShape(UnevenRoundedRectangle("))
        XCTAssertNil(root.range(of: #".sheet(item: $store.snapResultContext)"#))
        XCTAssertNil(root.range(of: #".sheet(item: $store.marketplacePickerContext)"#))
        XCTAssertNil(root.range(of: #".sheet(item: $store.listingContext)"#))

        let flowContent = try sheetBlock(
            in: root,
            startingWith: #"private struct FlowSheetContent"#,
            endingBefore: #"struct SplashView"#
        )

        XCTAssertNotNil(flowContent.range(of: "case .snapResult(let context):"))
        XCTAssertNotNil(flowContent.range(of: "SnapResultSheet(context: context)"))
        XCTAssertNotNil(flowContent.range(of: "case .marketplacePicker(let context):"))
        XCTAssertNotNil(flowContent.range(of: "MarketplacePickerSheet(context: context)"))
        XCTAssertNotNil(flowContent.range(of: "case .listing(let context):"))
        XCTAssertNotNil(flowContent.range(of: "ListingSheet(context: context)"))
        XCTAssertNotNil(flowContent.range(of: "case nil:"))
        XCTAssertNotNil(flowContent.range(of: "Color.clear"))
        XCTAssertNotNil(flowContent.range(of: ".accessibilityElement(children: .contain)"))
        XCTAssertNotNil(flowContent.range(of: ".accessibilityAddTraits(.isModal)"))
        XCTAssertNotNil(flowContent.range(of: ".accessibilitySortPriority(1_000)"))
    }

    func testSellingFlowSheetUsesNativeDetentPolicy() throws {
        let root = try appRouterSource()

        XCTAssertNotNil(root.range(of: "private var flowSheetBinding: Binding<Bool>"))
        XCTAssertNotNil(root.range(of: "appStore.flowSheetContext != nil"))
        XCTAssertNotNil(root.range(of: "private var flowSheetDetents: Set<PresentationDetent>"))
        XCTAssertNotNil(root.range(of: "case .snapResult:\n            [.large]"))
        XCTAssertNotNil(root.range(of: "case .marketplacePicker, .listing:\n            [.large]"))
        XCTAssertNil(root.range(of: "@State private var flowSheetDetent"))
        XCTAssertNil(root.range(of: "preferredFlowSheetDetent"))
        XCTAssertNil(root.range(of: "FlowSheetAdjustableActionModifier"))
        XCTAssertNil(root.range(of: "accessibilityAdjustableAction"))
    }

    func testNativeFlowSheetPresentationHelperUsesSystemDetentsAndMaterialFallback() throws {
        let material = try String(contentsOf: projectURL("BuySellAI/Design/NativeMaterialSurface.swift"), encoding: .utf8)
        let helper = try sheetBlock(
            in: material,
            startingWith: #"private struct NativeSystemFlowSheetPresentationModifier"#,
            endingBefore: #"extension View"#
        )

        XCTAssertNotNil(helper.range(of: "let detents: Set<PresentationDetent>"))
        XCTAssertNotNil(helper.range(of: ".presentationDetents(detents)"))
        XCTAssertNotNil(helper.range(of: ".presentationDragIndicator(.visible)"))
        XCTAssertNotNil(helper.range(of: ".presentationCornerRadius(28)"))
        XCTAssertNotNil(helper.range(of: ".presentationBackground(.regularMaterial)"))
        XCTAssertNotNil(material.range(of: "func nativeSystemFlowSheetPresentationChrome("))
        XCTAssertNotNil(material.range(of: "modifier(NativeSystemFlowSheetPresentationModifier(detents: detents))"))
    }

    func testSellingFlowAvoidsHandRolledBackdropDismissal() throws {
        let root = try appRouterSource()

        XCTAssertNotNil(root.range(of: #".sheet(isPresented: flowSheetBinding)"#))
        XCTAssertNotNil(root.range(of: "if isPresented == false {\n                appStore.dismissFlowSheet()"))
        XCTAssertNil(root.range(of: "Color.brand.shadow.opacity(0.10)"))
        XCTAssertNil(root.range(of: ".contentShape(Rectangle())"))
        XCTAssertNil(root.range(of: ".onTapGesture"))
        XCTAssertNil(root.range(of: "DragGesture(minimumDistance: 8)"))
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
