import XCTest

final class HapticRoutingTests: XCTestCase {
    func testCopyListingUsesSuccessNotificationWithoutPrimaryImpact() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)

        XCTAssertTrue(
            source.contains(#"PrimaryPillButton(title: "Copy listing", systemImage: "doc.on.doc.fill", hapticStyle: nil)"#),
            "Copy listing should not fire the generic primary-button impact before its success notification."
        )
        XCTAssertTrue(
            source.contains("Haptics.notify(.success)"),
            "Copy listing should keep the success notification haptic required by the spec."
        )
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
