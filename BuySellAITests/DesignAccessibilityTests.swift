import XCTest
import SwiftUI
@testable import BuySellAI

final class DesignAccessibilityTests: XCTestCase {
    func testIconCircleButtonKeepsMinimumTapTargetForSmallVisualControls() {
        XCTAssertEqual(IconCircleButton.minimumTapTarget, 44)
        XCTAssertEqual(IconCircleButton.tapTargetSize(for: 40), 44)
        XCTAssertEqual(IconCircleButton.tapTargetSize(for: 44), 44)
        XCTAssertEqual(IconCircleButton.tapTargetSize(for: 56), 56)
    }

    func testAccessibleBorderUsesStrongTokenWhenDifferentiatingWithoutColor() {
        XCTAssertEqual(Color.brand.accessibilityBorderToken(differentiateWithoutColor: false), .standard)
        XCTAssertEqual(Color.brand.accessibilityBorderToken(differentiateWithoutColor: true), .strong)
    }

    func testAppReduceMotionParticipatesInSharedMotionDecisions() {
        XCTAssertFalse(AppMotion.shouldReduceMotion(os: false, app: false))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: true, app: false))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: false, app: true))
        XCTAssertTrue(AppMotion.shouldReduceMotion(os: true, app: true))
    }

    func testBrandTextStylesUseStaticFontFacesAndBoldTextVariants() {
        XCTAssertEqual(BrandTextStyle.display.fontResourceName(), "SpaceGrotesk-Bold")
        XCTAssertEqual(BrandTextStyle.titleXL.fontResourceName(), "SpaceGrotesk-SemiBold")
        XCTAssertEqual(BrandTextStyle.titleLg.fontResourceName(), "SpaceGrotesk-SemiBold")
        XCTAssertEqual(BrandTextStyle.title.fontResourceName(), "SpaceGrotesk-SemiBold")
        XCTAssertEqual(BrandTextStyle.bodyLg.fontResourceName(), "Inter-Medium")
        XCTAssertEqual(BrandTextStyle.body.fontResourceName(), "Inter-Regular")
        XCTAssertEqual(BrandTextStyle.caption.fontResourceName(), "Inter-Medium")
        XCTAssertEqual(BrandTextStyle.overline.fontResourceName(), "Inter-SemiBold")
        XCTAssertEqual(BrandTextStyle.button.fontResourceName(), "SpaceGrotesk-SemiBold")

        for style in BrandTextStyle.allCases {
            XCTAssertTrue(style.fontResourceName(legibilityWeight: .bold).hasSuffix("-Bold"))
        }
        XCTAssertEqual(BrandTextStyle.body.fontResourceName(legibilityWeight: .bold), "Inter-Bold")
        XCTAssertEqual(BrandTextStyle.button.fontResourceName(legibilityWeight: .bold), "SpaceGrotesk-Bold")
    }

    func testMarketplaceAccessibilityLabelsDescribePayoutAndDelta() {
        let below = MarketplaceEstimate(id: .ebay, payout: Decimal(41), deltaPct: -8.2, badge: .none)
        XCTAssertEqual(
            MarketplaceAccessibilityText.estimateLabel(for: below),
            "eBay, estimated payout 41 dollars, 8 percent below average"
        )

        let above = MarketplaceEstimate(id: .craigslist, payout: Decimal(45), deltaPct: 12.4, badge: .best)
        XCTAssertEqual(
            MarketplaceAccessibilityText.summaryLabel("Best", for: above),
            "Best, Craigslist, estimated payout 45 dollars, 12 percent above average"
        )

        let average = MarketplaceEstimate(id: .facebook, payout: Decimal(43), deltaPct: 0.2, badge: .none)
        XCTAssertEqual(
            MarketplaceAccessibilityText.estimateLabel(for: average),
            "Facebook, estimated payout 43 dollars, average payout"
        )
    }

    func testHistoryAccessibilityLabelIncludesDecodedThumbnailStatus() {
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            itemName: "Lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: ImageTools.sampleJPEG(),
            marketplace: .ebay,
            listingText: "TITLE:\nLamp"
        )

        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: entry.imageThumbnail), "photo attached")
        XCTAssertEqual(
            HistoryAccessibilityText.rowLabel(for: entry, relativeDate: "2h ago"),
            "Lamp, eBay, 2h ago, photo attached"
        )
        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: Data([0x00, 0x01])), "no photo")
        XCTAssertEqual(HistoryAccessibilityText.thumbnailStatus(for: nil), "no photo")
    }

    func testChipAccessibilityLabelsDescribeControlAndCurrentValue() {
        XCTAssertEqual(
            ChipAccessibilityText.valueLabel("Category", value: "Furniture"),
            "Category, Furniture"
        )
        XCTAssertEqual(
            ChipAccessibilityText.valueLabel("Condition", value: "Like New"),
            "Condition, Like New"
        )
    }

    func testButtonsAvoidEmptyAccessibilityHints() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "optionalAccessibilityHint(accessibilityHint)"))
        XCTAssertNil(source.range(of: #"accessibilityHint\?\.\S+\s*\?\?\s*"""#, options: .regularExpression))
    }

    func testSnapResultChipsExposePurposeAndActionHints() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"ChipAccessibilityText.valueLabel("Category""#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint: "Changes the category""#))
        XCTAssertNotNil(source.range(of: #"ChipAccessibilityText.valueLabel("Condition""#))
        XCTAssertNotNil(source.range(of: #"accessibilityHint: "Changes the condition""#))
    }

    func testAnimatedSurfacesUseSharedReduceMotionDecision() throws {
        let root = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let buttons = try String(contentsOf: projectURL("BuySellAI/Design/Buttons.swift"), encoding: .utf8)
        let toast = try String(contentsOf: projectURL("BuySellAI/Design/Toast.swift"), encoding: .utf8)
        let camera = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)
        let tutorial = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(root.range(of: #".environment(\.appReduceMotion, appStore.reduceMotion)"#))
        XCTAssertGreaterThanOrEqual(buttons.components(separatedBy: "AppMotion.shouldReduceMotion").count - 1, 3)
        XCTAssertNotNil(toast.range(of: "AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)"))
        XCTAssertNotNil(camera.range(of: "AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)"))
        XCTAssertNotNil(camera.range(of: ".task(id: shouldReduceMotion)"))
        XCTAssertGreaterThanOrEqual(tutorial.components(separatedBy: "AppMotion.shouldReduceMotion").count - 1, 2)
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
