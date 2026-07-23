import XCTest
@testable import BuySellAI

final class AnalysisFeedbackTests: XCTestCase {
    func testAnalysisFeedbackUsesPromptNotificationTypes() {
        XCTAssertEqual(AnalysisFeedback.successNotificationType, .success)
        XCTAssertEqual(AnalysisFeedback.failureNotificationType, .error)
    }

    func testSnapResultStoreRoutesTerminalAnalysisCompletionThroughFeedbackHelper() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultStore.swift"), encoding: .utf8)

        XCTAssertEqual(source.components(separatedBy: "AnalysisFeedback.performSuccess()").count - 1, 1)
        XCTAssertEqual(source.components(separatedBy: "AnalysisFeedback.performFailure()").count - 1, 1)
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
