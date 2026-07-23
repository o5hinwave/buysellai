import XCTest
@testable import BuySellAI

final class ReviewPromptGateTests: XCTestCase {
    func testReviewPromptGateAllowsOnePromptPerVersionAfterMarkingRequested() throws {
        let suiteName = "ReviewPromptGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gate = ReviewPromptGate(defaults: defaults)

        XCTAssertTrue(gate.canRequestReview(for: "1.0"))
        gate.markReviewRequested(for: "1.0")
        XCTAssertFalse(gate.canRequestReview(for: "1.0"))

        XCTAssertTrue(gate.canRequestReview(for: "1.1"))
        gate.markReviewRequested(for: "1.1")
        XCTAssertFalse(gate.canRequestReview(for: "1.1"))
    }

    func testReviewPromptGateDoesNotConsumeEligibilityUntilMarkedRequested() throws {
        let suiteName = "ReviewPromptGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gate = ReviewPromptGate(defaults: defaults)

        XCTAssertTrue(gate.canRequestReview(for: "1.0"))
        XCTAssertTrue(gate.canRequestReview(for: "1.0"))
        XCTAssertNil(defaults.string(forKey: "lastReviewPromptVersion"))
    }

    func testSettingsMarksReviewPromptOnlyAfterStoreKitRequestCanRun() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let requestRange = try XCTUnwrap(source.range(of: "private func requestReview()"))
        let versionGateRange = try XCTUnwrap(source.range(of: "reviewPromptGate.canRequestReview", range: requestRange.upperBound..<source.endIndex))
        let sceneGuardRange = try XCTUnwrap(source.range(of: "guard let scene = reviewPromptScene", range: requestRange.upperBound..<source.endIndex))
        let storeKitRange = try XCTUnwrap(source.range(of: "SKStoreReviewController.requestReview(in: scene)", range: requestRange.upperBound..<source.endIndex))
        let markRange = try XCTUnwrap(source.range(of: "reviewPromptGate.markReviewRequested(for: appVersion)", range: requestRange.upperBound..<source.endIndex))

        XCTAssertLessThan(versionGateRange.lowerBound, sceneGuardRange.lowerBound)
        XCTAssertLessThan(sceneGuardRange.lowerBound, storeKitRange.lowerBound)
        XCTAssertLessThan(storeKitRange.lowerBound, markRange.lowerBound)
    }

    func testSettingsReviewPromptUsesForegroundActiveScene() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let sceneRange = try XCTUnwrap(source.range(of: "private var reviewPromptScene: UIWindowScene?"))
        let appVersionRange = try XCTUnwrap(source.range(of: "private var appVersion", range: sceneRange.upperBound..<source.endIndex))
        let helper = String(source[sceneRange.lowerBound..<appVersionRange.lowerBound])

        XCTAssertNotNil(helper.range(of: "UIApplication.shared.connectedScenes"))
        XCTAssertNotNil(helper.range(of: ".compactMap { $0 as? UIWindowScene }"))
        XCTAssertNotNil(helper.range(of: ".filter { $0.activationState == .foregroundActive }"))
        XCTAssertNotNil(helper.range(of: ".first"))
    }

    func testSettingsShowsToastWhenStoreKitSceneIsUnavailable() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let requestRange = try XCTUnwrap(source.range(of: "private func requestReview()"))
        let sceneGuardRange = try XCTUnwrap(source.range(of: "guard let scene = reviewPromptScene", range: requestRange.upperBound..<source.endIndex))
        let fallbackToastRange = try XCTUnwrap(source.range(of: #"appStore.showToast("Rating isn't available right now.".localized, style: .info)"#, range: sceneGuardRange.upperBound..<source.endIndex))
        let fallbackReturnRange = try XCTUnwrap(source.range(of: "return", range: fallbackToastRange.upperBound..<source.endIndex))
        let storeKitRange = try XCTUnwrap(source.range(of: "SKStoreReviewController.requestReview(in: scene)", range: requestRange.upperBound..<source.endIndex))
        let markRange = try XCTUnwrap(source.range(of: "reviewPromptGate.markReviewRequested(for: appVersion)", range: requestRange.upperBound..<source.endIndex))

        XCTAssertLessThan(sceneGuardRange.lowerBound, fallbackToastRange.lowerBound)
        XCTAssertLessThan(fallbackToastRange.lowerBound, fallbackReturnRange.lowerBound)
        XCTAssertLessThan(fallbackReturnRange.lowerBound, storeKitRange.lowerBound)
        XCTAssertLessThan(storeKitRange.lowerBound, markRange.lowerBound)
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
