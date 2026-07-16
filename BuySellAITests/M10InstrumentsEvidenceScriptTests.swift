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
        XCTAssertNotNil(script.range(of: "require_metadata_number"))
        XCTAssertNotNil(script.range(of: "require_metadata_date"))
        XCTAssertNotNil(script.range(of: "require_metadata_terms"))
        XCTAssertNotNil(script.range(of: "require_metadata_any_term"))
        XCTAssertNotNil(script.range(of: "must use YYYY-MM-DD"))
        XCTAssertNotNil(script.range(of: "a physical iPhone or iPad model"))
        XCTAssertNotNil(script.range(of: "signed archive artifact"))
        XCTAssertNotNil(script.range(of: "evidence_dir"))
        XCTAssertNotNil(script.range(of: #"trace_path="${evidence_dir}/${trace_path}""#))
        XCTAssertNotNil(script.range(of: "retained trace path does not exist"))
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
        XCTAssertNotNil(evidence.range(of: "Metadata is validated too"))
        XCTAssertNotNil(evidence.range(of: "`Date` must use `YYYY-MM-DD`"))
        XCTAssertNotNil(evidence.range(of: "`Device model` must mention iPhone or iPad"))
        XCTAssertNotNil(evidence.range(of: "`Device model` must also include the real-device preflight `device name:` value"))
        XCTAssertNotNil(evidence.range(of: "`iOS version` and `Release build` must include numeric values"))
        XCTAssertNotNil(evidence.range(of: "`Signed archive` must mention an archive"))
        XCTAssertNotNil(evidence.range(of: "`Signed archive` must also include the signed-preflight `archive:` path"))
        XCTAssertNotNil(evidence.range(of: "metadata values must point to retained trace files or directories"))
        XCTAssertNotNil(evidence.range(of: "Relative paths are resolved from this evidence file's directory"))
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
        XCTAssertNotNil(script.range(of: #"Instruments signed archive metadata"#))
        XCTAssertNotNil(script.range(of: #"Instruments device metadata"#))
        XCTAssertNotNil(script.range(of: #"$instruments_evidence" "Signed archive" "$signed_log" "archive:"#))
        XCTAssertNotNil(script.range(of: #"$instruments_evidence" "Device model" "$real_device_log" "device name:"#))
        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md"))
        XCTAssertNotNil(readme.range(of: "ALLOW_PENDING_INSTRUMENTS=1"))
        XCTAssertNotNil(readme.range(of: "generic \"passed\" notes are intentionally rejected"))
        XCTAssertNotNil(readme.range(of: "Instruments metadata is validated too"))
        XCTAssertNotNil(readme.range(of: "YYYY-MM-DD"))
        XCTAssertNotNil(readme.range(of: "iPhone or iPad device model that includes the real-device preflight `device name:` value"))
        XCTAssertNotNil(readme.range(of: "numeric iOS and release-build values"))
        XCTAssertNotNil(readme.range(of: "signed-archive wording with the signed-preflight `archive:` path"))
        XCTAssertNotNil(readme.range(of: "release-build metadata matching the signed-preflight `release build:` marker"))
        XCTAssertNotNil(readme.range(of: "trace metadata must point to retained files or directories"))
        XCTAssertNotNil(readme.range(of: "relative paths resolved from the evidence file"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md"))
        XCTAssertNotNil(m10.range(of: "ALLOW_PENDING_INSTRUMENTS=1"))
        XCTAssertNotNil(m10.range(of: "Run the M10 Instruments evidence verifier"))
        XCTAssertNotNil(m10.range(of: "the Instruments `Signed archive` metadata references the same signed-preflight `archive:` path"))
        XCTAssertNotNil(m10.range(of: "acceptance and Instruments `Release build` metadata match the signed-preflight `release build:` value"))
        XCTAssertNotNil(m10.range(of: "Instruments `Device model` metadata reference the real-device preflight `device name:` value"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
