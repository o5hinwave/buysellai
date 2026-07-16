import Foundation
import XCTest

final class M10AppStoreMetadataScriptTests: XCTestCase {
    func testMetadataVerifierRequiresConcreteAppStoreConnectSubmissionFields() throws {
        let scriptURL = projectURL("Scripts/verify_m10_app_store_metadata.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "ALLOW_PENDING_METADATA"))
        XCTAssertNotNil(script.range(of: "M10_APP_STORE_METADATA"))
        XCTAssertNotNil(script.range(of: "App name"))
        XCTAssertNotNil(script.range(of: "Bundle ID"))
        XCTAssertNotNil(script.range(of: "SKU"))
        XCTAssertNotNil(script.range(of: "Primary category"))
        XCTAssertNotNil(script.range(of: "Age rating"))
        XCTAssertNotNil(script.range(of: "DSA trader status"))
        XCTAssertNotNil(script.range(of: "Support URL"))
        XCTAssertNotNil(script.range(of: "Privacy Policy URL"))
        XCTAssertNotNil(script.range(of: "Screenshots"))
        XCTAssertNotNil(script.range(of: "App Review notes"))
        XCTAssertNotNil(script.range(of: "Export compliance"))
        XCTAssertNotNil(script.range(of: "metadata '$field' is not recorded"))
        XCTAssertNotNil(script.range(of: "metadata '$field' must be a full https URL"))
        XCTAssertNotNil(script.range(of: "expected <= ${max_bytes}"))
        XCTAssertNotNil(script.range(of: "M10 App Store metadata evidence passed"))
    }

    func testMetadataVerifierRequiresPrivacyAnswersToMatchManifestScope() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_app_store_metadata.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "App privacy data types"))
        XCTAssertNotNil(script.range(of: "email address"))
        XCTAssertNotNil(script.range(of: "user id"))
        XCTAssertNotNil(script.range(of: "photos or videos"))
        XCTAssertNotNil(script.range(of: "other user content"))
        XCTAssertNotNil(script.range(of: #"require_exact "Data linked to user" "Yes""#))
        XCTAssertNotNil(script.range(of: #"require_exact "Data used for tracking" "No""#))
        XCTAssertNotNil(script.range(of: #"require_exact "Tracking domains" "None""#))
        XCTAssertNotNil(script.range(of: #"require_exact "Data use purpose" "App Functionality""#))
        XCTAssertNotNil(script.range(of: "delete account"))
        XCTAssertNotNil(script.range(of: "itsappusesnonexemptencryption=false"))
        XCTAssertNotNil(script.range(of: "https"))
    }

    func testMetadataTemplateAndDocsRouteThroughVerifier() throws {
        let metadataURL = projectURL("M10_APP_STORE_METADATA.md")
        let metadata = try String(contentsOf: metadataURL, encoding: .utf8)
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        XCTAssertNotNil(metadata.range(of: "App Store Connect metadata"))
        XCTAssertNotNil(metadata.range(of: "App privacy data types"))
        XCTAssertNotNil(metadata.range(of: "Email Address, User ID, Photos or Videos, Other User Content"))
        XCTAssertNotNil(metadata.range(of: "ALLOW_PENDING_METADATA=1"))
        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-submit-readiness-app-store-metadata.log"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md"))
        XCTAssertNotNil(m10.range(of: "Complete App Store Connect metadata"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-app-store-metadata.log"))
    }

    func testCombinedSubmitReadinessRequiresMetadataEvidenceLog() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10_APP_STORE_METADATA"))
        XCTAssertNotNil(script.range(of: "M10_APP_STORE_METADATA_LOG"))
        XCTAssertNotNil(script.range(of: "/tmp/buysell-submit-readiness-app-store-metadata.log"))
        XCTAssertNotNil(script.range(of: "M10 App Store metadata evidence passed"))
        XCTAssertNotNil(script.range(of: "App Store metadata evidence log"))
        XCTAssertNotNil(script.range(of: "M10AppStoreMetadataScriptTests/testMetadataVerifierRequiresConcreteAppStoreConnectSubmissionFields"))
        XCTAssertNotNil(script.range(of: "App Store metadata evidence is incomplete"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
