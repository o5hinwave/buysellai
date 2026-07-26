import XCTest

final class SettingsViewLifecycleTests: XCTestCase {
    func testSettingsShowsQuietEarlyAccessLabelWithoutPaywallCopy() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let snap = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)
        let questions = try String(contentsOf: projectURL("BuySellAI/Features/ItemQuestions/ItemQuestionsSheet.swift"), encoding: .utf8)
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Features/MarketplacePicker/MarketplacePickerSheet.swift"), encoding: .utf8)
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(settings.range(of: #"title: "Free during early access""#))
        XCTAssertNotNil(settings.range(of: #"value: appStore.earlyAccessStatusValue"#))
        XCTAssertNotNil(settings.range(of: #"BuySell is free during early access while we improve item identification, pricing research, and marketplace recommendations."#))
        XCTAssertNil(settings.range(of: #"paywall"#, options: .caseInsensitive))
        XCTAssertNil(settings.range(of: #"subscription"#, options: .caseInsensitive))
        XCTAssertNil(settings.range(of: #"trial"#, options: .caseInsensitive))
        XCTAssertNil(home.range(of: #"Free during early access"#))
        XCTAssertNil(snap.range(of: #"Free during early access"#))
        XCTAssertNil(questions.range(of: #"Free during early access"#))
        XCTAssertNil(marketplace.range(of: #"Free during early access"#))
        XCTAssertNil(listing.range(of: #"Free during early access"#))
    }

    func testDeleteAccountTaskIsOwnedAndCancelledWithConfirmationView() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let deleteViewRange = try XCTUnwrap(settings.range(of: "private struct DeleteAccountView"))
        let safariRange = try XCTUnwrap(settings.range(of: "private struct SafariDestination", range: deleteViewRange.upperBound..<settings.endIndex))
        let deleteView = String(settings[deleteViewRange.lowerBound..<safariRange.lowerBound])

        XCTAssertNotNil(deleteView.range(of: "@State private var deleteAccountTask: Task<Void, Never>?"))
        XCTAssertNotNil(deleteView.range(of: "deleteAccountTask = Task { @MainActor in"))
        XCTAssertNotNil(deleteView.range(of: "guard Task.isCancelled == false else { return }"))
        XCTAssertNotNil(deleteView.range(of: ".onDisappear {\n            deleteAccountTask?.cancel()\n            deleteAccountTask = nil\n        }"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
