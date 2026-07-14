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
}
