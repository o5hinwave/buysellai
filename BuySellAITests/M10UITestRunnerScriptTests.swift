import Foundation
import XCTest

final class M10UITestRunnerScriptTests: XCTestCase {
    func testChunkedUITestRunnerRunsEveryUITestWithIsolatedResultBundles() throws {
        let scriptURL = projectURL("Scripts/run_m10_ui_tests.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let uiTestSource = try String(contentsOf: projectURL("BuySellAIUITests/BuySellAIUITests.swift"), encoding: .utf8)
        let expectedTests = Set(try uiTestNames(in: uiTestSource).map { "BuySellAIUITests/BuySellAIUITests/\($0)" })
        let configuredTests = Set(try runnerTestIDs(in: script))

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
        XCTAssertGreaterThanOrEqual(expectedTests.count, 33)
        XCTAssertEqual(configuredTests, expectedTests)
        XCTAssertNotNil(script.range(of: "M10_UI_RESULT_ROOT"))
        XCTAssertNotNil(script.range(of: "M10_UI_CONTINUE_ON_FAILURE"))
        XCTAssertNotNil(script.range(of: "M10_UI_TEST_TIMEOUT_SECONDS"))
        XCTAssertNotNil(script.range(of: "M10_UI_MAX_ATTEMPTS"))
        XCTAssertNotNil(script.range(of: "M10_UI_SNAPSHOT_ROOT"))
        XCTAssertNotNil(script.range(of: "prepare_snapshot"))
        XCTAssertNotNil(script.range(of: "M10_TODAY_FEATURE_NOMINATION.md"))
        XCTAssertNotNil(script.range(of: #"M10_UI_SNAPSHOT_ROOT must be under /tmp"#))
        XCTAssertNotNil(script.range(of: "M10_SNAPSHOT_COPY_TIMEOUT"))
        XCTAssertNotNil(script.range(of: "copy_snapshot_entry"))
        XCTAssertNotNil(script.range(of: #"rsync -a "$source" "$target/""#))
        XCTAssertNotNil(script.range(of: #"ditto "$source" "${target}/${entry}""#))
        XCTAssertNotNil(script.range(of: #"cd "$xcodebuild_workdir""#))
        XCTAssertNotNil(script.range(of: "xcodebuild workdir: $xcodebuild_workdir"))
        XCTAssertNotNil(script.range(of: "snapshot root: $snapshot_root"))
        XCTAssertNotNil(script.range(of: "is_retryable_failure"))
        XCTAssertNotNil(script.range(of: "Simulator device failed to launch"))
        XCTAssertNotNil(script.range(of: "Application failed preflight checks"))
        XCTAssertNotNil(script.range(of: "waiting for workers to materialize"))
        XCTAssertNotNil(script.range(of: "IDELaunchiPhoneSimulatorLauncher"))
        XCTAssertNotNil(script.range(of: "timed out after [0-9]+ seconds"))
        XCTAssertNotNil(script.range(of: #"[[ "$status" -eq 124 ]]"#))
        XCTAssertNotNil(script.range(of: "-parallel-testing-enabled NO"))
        XCTAssertNotNil(script.range(of: "-maximum-concurrent-test-simulator-destinations 1"))
        XCTAssertNotNil(script.range(of: #"-only-testing:"$test_id""#))
        XCTAssertNotNil(script.range(of: "-resultBundlePath \"$result_bundle\""))
        XCTAssertNotNil(script.range(of: "M10 UI chunked tests passed"))
        XCTAssertNotNil(script.range(of: "M10 UI chunked tests failed"))
        XCTAssertNotNil(script.range(of: "result bundle: $result_bundle"))
        XCTAssertNotNil(script.range(of: "test: $test_id"))
        XCTAssertNotNil(script.range(of: "summary.log"))
    }

    func testDocsDescribeChunkedUITestRunnerEvidence() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/run_m10_ui_tests.sh"))
        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_ui_evidence.sh"))
        XCTAssertNotNil(readme.range(of: "M10_UI_CONTINUE_ON_FAILURE=1"))
        XCTAssertNotNil(readme.range(of: "M10_UI_SNAPSHOT_ROOT=/tmp/buysell-m10-ui-worktree"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-submit-readiness-ui.log"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-m10-ui-tests/summary.log"))
        XCTAssertNotNil(m10.range(of: "Scripts/run_m10_ui_tests.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_ui_evidence.sh"))
        XCTAssertNotNil(m10.range(of: "M10_UI_CONTINUE_ON_FAILURE=1"))
        XCTAssertNotNil(m10.range(of: "M10_UI_SNAPSHOT_ROOT=/tmp/buysell-m10-ui-worktree"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-ui.log"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-m10-ui-tests/summary.log"))
        XCTAssertNotNil(readme.range(of: "M10_SNAPSHOT_COPY_TIMEOUT"))
        XCTAssertNotNil(m10.range(of: "M10_SNAPSHOT_COPY_TIMEOUT"))
    }

    func testUIEvidenceVerifierChecksChunkedResultBundles() throws {
        let scriptURL = projectURL("Scripts/verify_m10_ui_evidence.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "M10_UI_RESULT_ROOT"))
        XCTAssertNotNil(script.range(of: "M10_UI_TEST_SOURCE"))
        XCTAssertNotNil(script.range(of: "M10_MIN_UI_TESTS:-33"))
        XCTAssertNotNil(script.range(of: "BuySellAIUITests/BuySellAIUITests.swift"))
        XCTAssertNotNil(script.range(of: "M10 UI chunked tests passed"))
        XCTAssertNotNil(script.range(of: "M10 UI evidence passed"))
        XCTAssertNotNil(script.range(of: "xcrun xcresulttool get test-results summary"))
        XCTAssertNotNil(script.range(of: "xcrun xcresulttool get test-results tests"))
        XCTAssertNotNil(script.range(of: "nodeIdentifier"))
        XCTAssertNotNil(script.range(of: "tests: ${#expected_tests[@]}"))
        XCTAssertNotNil(script.range(of: "status: 0"))
        XCTAssertNotNil(script.range(of: "passed test: $test_id"))
        XCTAssertNotNil(script.range(of: "result bundle: $result_bundle"))
    }

    private func uiTestNames(in source: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: #"func\s+(test[A-Za-z0-9_]+)\(\)(?:\s+throws)?"#)
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: source) else {
                return nil
            }
            return String(source[range])
        }
    }

    private func runnerTestIDs(in script: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: #""(BuySellAIUITests/BuySellAIUITests/test[A-Za-z0-9_]+)""#)
        return regex.matches(in: script, range: NSRange(script.startIndex..., in: script)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: script) else {
                return nil
            }
            return String(script[range])
        }
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
