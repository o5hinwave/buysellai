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
}
