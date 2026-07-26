import XCTest

final class HapticRoutingTests: XCTestCase {
    func testCopyListingUsesSuccessNotificationWithoutPrimaryImpact() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)

        XCTAssertTrue(
            source.contains(#"Label("Copy listing".localized, systemImage: AppSymbol.Flow.copy)"#)
                && source.contains(".disabled(copyableListingText.isEmpty)")
                && source.contains("copyListing()"),
            "Copy listing should stay a native action wired to the validated copy path."
        )
        XCTAssertNil(
            source.range(of: #"PrimaryPillButton("#),
            "Copy listing should not fire the generic primary-button impact before its success notification."
        )
        XCTAssertTrue(
            source.contains("Haptics.notify(.success)"),
            "Copy listing should keep the success notification haptic required by the spec."
        )
    }

    func testSnapResultMenuOpenControlsFireLightHaptics() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let categoryMenu = try sourceBlock(
            in: source,
            startingWith: "private func categoryMenuButton",
            endingBefore: "private func conditionMenuButton"
        )
        let conditionMenu = try sourceBlock(
            in: source,
            startingWith: "private func conditionMenuButton",
            endingBefore: "@ViewBuilder\n    private func menuItemLabel"
        )

        for menuSource in [categoryMenu, conditionMenu] {
            XCTAssertNotNil(menuSource.range(of: ".buttonStyle(.bordered)"))
            XCTAssertNil(menuSource.range(of: ".buttonBorderShape(.capsule)"))
            XCTAssertNotNil(menuSource.range(of: ".simultaneousGesture(TapGesture().onEnded {"))
            XCTAssertNotNil(menuSource.range(of: "Haptics.impact(.light)"))
        }
    }

    func testSettingsDangerZoneNavigationActionUsesSharedHapticRow() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let dangerZone = try sourceBlock(
            in: source,
            startingWith: #"Section("Danger zone".localized)"#,
            endingBefore: #".navigationTitle("Settings".localized)"#
        )
        let actionRow = try sourceBlock(
            in: source,
            startingWith: "private struct SettingsActionRow: View",
            endingBefore: "private struct SettingsRowLabel: View"
        )

        XCTAssertNotNil(dangerZone.range(of: #"SettingsActionRow("#))
        XCTAssertNotNil(dangerZone.range(of: #"accessibilityIdentifier: "Settings.DeleteAccount""#))
        XCTAssertNotNil(dangerZone.range(of: #"showDeleteAccount = true"#))
        XCTAssertNotNil(source.range(of: #".navigationDestination(isPresented: $showDeleteAccount)"#))
        XCTAssertNotNil(actionRow.range(of: "Haptics.impact(.light)"))
        XCTAssertNotNil(actionRow.range(of: ".buttonStyle(.automatic)"))
        XCTAssertNil(actionRow.range(of: ".buttonStyle(PressButtonStyle())"))
        XCTAssertNil(dangerZone.range(of: ".simultaneousGesture(TapGesture().onEnded {"))
    }

    private func sourceBlock(in source: String, startingWith start: String, endingBefore end: String) throws -> String {
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
