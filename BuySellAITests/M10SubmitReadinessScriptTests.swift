import Foundation
import XCTest

final class M10SubmitReadinessScriptTests: XCTestCase {
    func testSubmitReadinessScriptAggregatesAllM10EvidenceGates() throws {
        let scriptURL = projectURL("Scripts/verify_m10_submit_readiness.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "M10_FULL_XCRESULT"))
        XCTAssertNotNil(script.range(of: "M10_FOCUSED_XCRESULT"))
        XCTAssertNotNil(script.range(of: "M10_MIN_TESTS:-296"))
        XCTAssertNotNil(script.range(of: "M10_MIN_FOCUSED_TESTS:-52"))
        XCTAssertNotNil(script.range(of: "M10_SIGNED_ARCHIVE"))
        XCTAssertNotNil(script.range(of: "M10_APP_STORE_ARCHIVE"))
        XCTAssertNotNil(script.range(of: "M10_APP_STORE_EXPORT"))
        XCTAssertNotNil(script.range(of: "M10_INSTRUMENTS_EVIDENCE"))
        XCTAssertNotNil(script.range(of: "xcrun xcresulttool get test-results summary"))
        XCTAssertNotNil(script.range(of: "require_xcresult_contains_tests"))
        XCTAssertNotNil(script.range(of: "require_same_marker_value"))
        XCTAssertNotNil(script.range(of: "require_metadata_references_marker_value"))
        XCTAssertNotNil(script.range(of: "markdown_metadata_value"))
        XCTAssertNotNil(script.range(of: "AppStoreValidationPreflightScriptTests/testAppStoreValidationPreflightChecksPrivacyManifestContents"))
        XCTAssertNotNil(script.range(of: "RealDevicePreflightScriptTests/testRealDeviceAcceptanceVerifierParsesTimingEvidenceInMillisecondsOrSeconds"))
        XCTAssertNotNil(script.range(of: "SigningCapabilityTests/testAppTargetBuildConfigurationsUseEntitlementsAndAutomaticSigning"))
        XCTAssertNotNil(script.range(of: "M10 local archive check passed"))
        XCTAssertNotNil(script.range(of: "M10 signed archive preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 App Store export preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 App Store validation preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 real-device preflight passed"))
        XCTAssertNotNil(script.range(of: "M10 secret scan passed"))
        XCTAssertNotNil(script.range(of: "M10 Instruments evidence passed"))
        XCTAssertNotNil(script.range(of: "verify_m10_real_device_acceptance.sh"))
    }

    func testSubmitReadinessScriptRequiresConcreteLogArtifactMarkers() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "require_directory \"$signed_archive\""))
        XCTAssertNotNil(script.range(of: "require_directory \"$app_store_archive\""))
        XCTAssertNotNil(script.range(of: "require_directory \"$app_store_export\""))
        XCTAssertNotNil(script.range(of: "archive: $no_sign_archive"))
        XCTAssertNotNil(script.range(of: "archive: $signed_archive"))
        XCTAssertNotNil(script.range(of: "archive: $app_store_archive"))
        XCTAssertNotNil(script.range(of: "export: $app_store_export"))
        XCTAssertNotNil(script.range(of: "ipa:"))
        XCTAssertNotNil(script.range(of: "validated IPA"))
        XCTAssertNotNil(script.range(of: "mismatch"))
        XCTAssertNotNil(script.range(of: "signed archive metadata"))
        XCTAssertNotNil(script.range(of: "App Store validation metadata"))
        XCTAssertNotNil(script.range(of: #"metadata '$metadata_field' must reference '$marker_path'"#))
        XCTAssertNotNil(script.range(of: #"$acceptance_file" "Signed archive" "$signed_log" "archive:"#))
        XCTAssertNotNil(script.range(of: #"$acceptance_file" "App Store validation" "$validation_log" "ipa:"#))
        XCTAssertNotNil(script.range(of: #"$instruments_evidence" "Signed archive" "$signed_log" "archive:"#))
        XCTAssertNotNil(script.range(of: "Instruments signed archive metadata"))
        XCTAssertNotNil(script.range(of: "device:"))
        XCTAssertNotNil(script.range(of: "full suite: $full_result"))
        XCTAssertNotNil(script.range(of: "archive log: $no_sign_log"))
        XCTAssertNotNil(script.range(of: "performance tests:"))
        XCTAssertNotNil(script.range(of: "app size:"))
        XCTAssertNotNil(script.range(of: "file: $instruments_evidence"))
    }

    func testSubmitReadinessScriptRequiresFinalAcceptanceDocsToBeComplete() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "require_submit_checkboxes"))
        XCTAssertNotNil(script.range(of: "Submit-Ready Gates"))
        XCTAssertNotNil(script.range(of: "unchecked Submit-Ready Gates"))
        XCTAssertNotNil(script.range(of: "require_result_log_final"))
        XCTAssertNotNil(script.range(of: "is_placeholder_value"))
        XCTAssertNotNil(script.range(of: "Result Log row"))
        XCTAssertNotNil(script.range(of: "Result Log"))
        XCTAssertNotNil(script.range(of: "Result Log needs at least one completed Pass row"))
        XCTAssertNotNil(script.range(of: "Result Log has no completed Pass row"))
        XCTAssertNotNil(script.range(of: "Result Log still has pending rows"))
        XCTAssertNotNil(script.range(of: "Notes must mention final evidence"))
        XCTAssertNotNil(script.range(of: "signed archive"))
        XCTAssertNotNil(script.range(of: "App Store validation"))
        XCTAssertNotNil(script.range(of: "real-device acceptance"))
        XCTAssertNotNil(script.range(of: "Instruments evidence"))
        XCTAssertNotNil(script.range(of: "expected Pass"))
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
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-instruments.log"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-combined.log"))
        XCTAssertNotNil(readme.range(of: "The final `Result Log` must include a complete `Pass` row"))
        XCTAssertNotNil(readme.range(of: "The combined gate expects retained artifact markers"))
        XCTAssertNotNil(readme.range(of: "same `ipa:` path produced by the export preflight"))
        XCTAssertNotNil(readme.range(of: "manual acceptance and Instruments metadata reference the signed-preflight `archive:` path"))
        XCTAssertNotNil(readme.range(of: "M10_SIGNED_ARCHIVE"))
        XCTAssertNotNil(readme.range(of: "M10_APP_STORE_EXPORT"))
        XCTAssertNotNil(m10.range(of: "pass logs retain their concrete artifact markers"))
        XCTAssertNotNil(m10.range(of: "same `ipa:` path produced by the export preflight"))
        XCTAssertNotNil(m10.range(of: "acceptance `Signed archive` metadata references the signed-preflight `archive:` path"))
        XCTAssertNotNil(m10.range(of: "acceptance `App Store validation` metadata references the validated `ipa:` path"))
        XCTAssertNotNil(m10.range(of: "Instruments `Signed archive` metadata references the same signed-preflight `archive:` path"))
        XCTAssertNotNil(m10.range(of: "real-device `device:`"))
        XCTAssertNotNil(m10.range(of: "Instruments `file:`"))
        XCTAssertNotNil(m10.range(of: "Every field must be concrete"))
        XCTAssertNotNil(m10.range(of: "`Result` must be `Pass`"))
        XCTAssertNotNil(readme.range(of: "The Notes field must mention the signed archive, App Store validation, real-device acceptance, and Instruments evidence"))
        XCTAssertNotNil(m10.range(of: "`Notes` must mention the signed archive, App Store validation, real-device acceptance, and Instruments evidence"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
