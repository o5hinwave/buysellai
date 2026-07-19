import Foundation
import XCTest

final class M10PerformanceEvidenceScriptTests: XCTestCase {
    func testPerformanceEvidenceScriptRequiresFullSuiteAndNamedBudgetTests() throws {
        let scriptURL = projectURL("Scripts/verify_m10_performance_evidence.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "M10_PERFORMANCE_XCRESULT"))
        XCTAssertNotNil(script.range(of: "M10_MIN_TESTS:-420"))
        XCTAssertNotNil(script.range(of: "xcrun xcresulttool get test-results summary"))
        XCTAssertNotNil(script.range(of: "xcrun xcresulttool get test-results tests"))
        XCTAssertNotNil(script.range(of: "testHomeLaunchReachesPrimaryActionWithinSimulatorBudget"))
        XCTAssertNotNil(script.range(of: "testCameraReadyOverlayAppearsWithinSimulatorBudget"))
        XCTAssertNotNil(script.range(of: "testCameraSampleCapturePresentsResultThumbnailWithinSimulatorBudget"))
        XCTAssertNotNil(script.range(of: "testSlowHistoryLoadDoesNotBlockHomeLaunch"))
        XCTAssertNotNil(script.range(of: "testHomeHandlesFiveHundredRecentListingsAndScrolls"))
        XCTAssertNotNil(script.range(of: "performance test: %s"))
    }

    func testPerformanceEvidenceScriptRequiresArchiveSizeBudget() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_performance_evidence.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10_PERFORMANCE_ARCHIVE_LOG"))
        XCTAssertNotNil(script.range(of: "M10_MAX_APP_SIZE_KB:-20480"))
        XCTAssertNotNil(script.range(of: "M10 local archive check passed"))
        XCTAssertNotNil(script.range(of: "marker_value"))
        XCTAssertNotNil(script.range(of: #"bundle_id="$(marker_value "bundle id:" "$archive_log")""#))
        XCTAssertNotNil(script.range(of: #"[[ "$bundle_id" == "com.rhodes.buysellai" ]]"#))
        XCTAssertNotNil(script.range(of: #"printf 'bundle id: %s\n' "$bundle_id""#))
        XCTAssertNotNil(script.range(of: "release build:"))
        XCTAssertNotNil(script.range(of: "app size:"))
        XCTAssertNotNil(script.range(of: "above ${max_app_size_kb}KB"))
    }

    func testCombinedSubmitReadinessRequiresPerformanceEvidenceLog() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10_PERFORMANCE_LOG"))
        XCTAssertNotNil(script.range(of: "/tmp/buysell-submit-readiness-performance.log"))
        XCTAssertNotNil(script.range(of: "M10 performance evidence passed"))
        XCTAssertNotNil(script.range(of: "performance evidence log"))
        XCTAssertNotNil(script.range(of: "required_performance_tests"))
        XCTAssertNotNil(script.range(of: "performance test: $test_id"))
    }

    func testDocsRouteThroughPerformanceEvidenceGate() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_performance_evidence.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_performance_evidence.sh"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-performance.log"))
        XCTAssertNotNil(m10.range(of: "Run the M10 performance evidence verifier"))
        XCTAssertNotNil(m10.range(of: "no-sign archive `bundle id:` and `release build:` markers"))
        XCTAssertNotNil(m10.range(of: "Run the M10 Instruments evidence verifier"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
