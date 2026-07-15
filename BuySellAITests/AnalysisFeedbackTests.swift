import XCTest
@testable import BuySellAI

final class AnalysisFeedbackTests: XCTestCase {
    func testAnalysisFeedbackUsesPromptNotificationTypes() {
        XCTAssertEqual(AnalysisFeedback.successNotificationType, .success)
        XCTAssertEqual(AnalysisFeedback.failureNotificationType, .error)
    }

    func testSnapResultStoreRoutesAnalysisCompletionThroughFeedbackHelper() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultStore.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "AnalysisFeedback.performSuccess()"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "AnalysisFeedback.performFailure()").count - 1, 2)
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
