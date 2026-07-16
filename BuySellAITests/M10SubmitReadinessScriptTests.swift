import Foundation
import XCTest

final class M10SubmitReadinessScriptTests: XCTestCase {
    func testSubmitReadinessScriptAggregatesAllM10EvidenceGates() throws {
        let scriptURL = projectURL("Scripts/verify_m10_submit_readiness.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "M10_FULL_XCRESULT"))
        XCTAssertNotNil(script.range(of: "M10_FOCUSED_XCRESULT"))
        XCTAssertNotNil(script.range(of: "M10_MIN_TESTS:-284"))
        XCTAssertNotNil(script.range(of: "M10_MIN_FOCUSED_TESTS:-29"))
        XCTAssertNotNil(script.range(of: "xcrun xcresulttool get test-results summary"))
        XCTAssertNotNil(script.range(of: "M10 local archive check passed"))
        XCTAssertNotNil(script.range(of: "M10 signed archive preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 App Store export preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 App Store validation preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 real-device preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 secret scan passed"))
        XCTAssertNotNil(script.range(of: "verify_m10_real_device_acceptance.sh"))
    }

    func testSubmitReadinessScriptRequiresFinalAcceptanceDocsToBeComplete() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "require_submit_checkboxes"))
        XCTAssertNotNil(script.range(of: "Submit-Ready Gates"))
        XCTAssertNotNil(script.range(of: "unchecked Submit-Ready Gates"))
        XCTAssertNotNil(script.range(of: "require_result_log_final"))
        XCTAssertNotNil(script.range(of: "Result Log"))
        XCTAssertNotNil(script.range(of: "Result Log still has pending rows"))
    }

    func testSubmitReadinessScriptHasPendingModeForExternalBlockers() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "ALLOW_PENDING_M10"))
        XCTAssertNotNil(script.range(of: "M10 submit readiness pending"))
        XCTAssertNotNil(script.range(of: "M10 submit readiness incomplete"))
        XCTAssertNotNil(script.range(of: "M10 submit readiness passed"))
        XCTAssertNotNil(script.range(of: "Complete every signed archive, App Store, real-device, and evidence item"))
    }

    func testAcceptanceDocsAndReadmeRouteThroughCombinedSubmitReadinessGate() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md"))
        XCTAssertNotNil(readme.range(of: "ALLOW_PENDING_M10=1"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md"))
        XCTAssertNotNil(m10.range(of: "ALLOW_PENDING_M10=1"))
        XCTAssertNotNil(m10.range(of: "Run the combined M10 submit-readiness gate without `ALLOW_PENDING_M10=1`"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-full.xcresult"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-combined.log"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
