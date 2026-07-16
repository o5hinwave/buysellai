import Foundation
import XCTest

final class M10InstrumentsEvidenceScriptTests: XCTestCase {
    func testInstrumentsEvidenceScriptRequiresPhysicalDeviceTraceMetadata() throws {
        let scriptURL = projectURL("Scripts/verify_m10_instruments_evidence.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "ALLOW_PENDING_INSTRUMENTS"))
        XCTAssertNotNil(script.range(of: "M10 Instruments evidence pending"))
        XCTAssertNotNil(script.range(of: "M10 Instruments evidence passed"))
        XCTAssertNotNil(script.range(of: "Time Profiler trace"))
        XCTAssertNotNil(script.range(of: "Allocations trace"))
        XCTAssertNotNil(script.range(of: "Home launch duration"))
        XCTAssertNotNil(script.range(of: "Camera ready duration"))
        XCTAssertNotNil(script.range(of: "Home steady memory"))
        XCTAssertNotNil(script.range(of: "require_evidence_terms"))
        XCTAssertNotNil(script.range(of: "require_evidence_any_term"))
    }

    func testInstrumentsEvidenceScriptEnforcesPromptBudgets() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_instruments_evidence.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "900"))
        XCTAssertNotNil(script.range(of: "400"))
        XCTAssertNotNil(script.range(of: "120"))
        XCTAssertNotNil(script.range(of: "Home scroll FPS"))
        XCTAssertNotNil(script.range(of: "no dropped"))
        XCTAssertNotNil(script.range(of: "P01"))
        XCTAssertNotNil(script.range(of: "P05"))
        XCTAssertNotNil(script.range(of: "Home launch timing proof"))
        XCTAssertNotNil(script.range(of: "camera preview timing proof"))
        XCTAssertNotNil(script.range(of: "scroll frame-rate proof"))
        XCTAssertNotNil(script.range(of: "memory allocation proof"))
        XCTAssertNotNil(script.range(of: "retained profiling trace proof"))
    }

    func testInstrumentsEvidenceDocStartsPendingWithRequiredRows() throws {
        let evidence = try String(contentsOf: projectURL("M10_INSTRUMENTS.md"), encoding: .utf8)

        XCTAssertNotNil(evidence.range(of: "Every Evidence cell must cite the observed profiling proof"))
        XCTAssertNotNil(evidence.range(of: "P01 `home`, `launch`, `ms`"))
        XCTAssertNotNil(evidence.range(of: "P02 `camera`, `preview`, `ms`"))
        XCTAssertNotNil(evidence.range(of: "P03 `scroll` plus either `fps` or `no dropped`"))
        XCTAssertNotNil(evidence.range(of: "P04 `memory`, `mb`"))
        XCTAssertNotNil(evidence.range(of: "P05 `time profiler`, `allocations`, `trace`"))
        XCTAssertNotNil(evidence.range(of: "Time Profiler"))
        XCTAssertNotNil(evidence.range(of: "Allocations"))
        XCTAssertNotNil(evidence.range(of: "under 900 ms"))
        XCTAssertNotNil(evidence.range(of: "within 400 ms"))
        XCTAssertNotNil(evidence.range(of: "120 fps"))
        XCTAssertNotNil(evidence.range(of: "under 120 MB"))
        XCTAssertNotNil(evidence.range(of: "| P01 |"))
        XCTAssertNotNil(evidence.range(of: "| P05 |"))
        XCTAssertNotNil(evidence.range(of: "| Pending | TBD |"))
    }

    func testCombinedSubmitReadinessRequiresInstrumentsEvidenceLogAndDocsRouteThroughGate() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10_INSTRUMENTS_LOG"))
        XCTAssertNotNil(script.range(of: "/tmp/buysell-submit-readiness-instruments.log"))
        XCTAssertNotNil(script.range(of: "M10 Instruments evidence passed"))
        XCTAssertNotNil(script.range(of: "Instruments evidence log"))
        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md"))
        XCTAssertNotNil(readme.range(of: "ALLOW_PENDING_INSTRUMENTS=1"))
        XCTAssertNotNil(readme.range(of: "generic \"passed\" notes are intentionally rejected"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md"))
        XCTAssertNotNil(m10.range(of: "ALLOW_PENDING_INSTRUMENTS=1"))
        XCTAssertNotNil(m10.range(of: "Run the M10 Instruments evidence verifier"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
