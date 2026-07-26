import Foundation
import XCTest

final class AppStoreCloudCredentialsScriptTests: XCTestCase {
    func testCloudCredentialScriptReportsRequiredSecretsWithoutPrintingValues() throws {
        let scriptURL = projectURL("Scripts/verify_app_store_cloud_credentials.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "App Store cloud credential check"))
        XCTAssertNotNil(script.range(of: "signed archive, App Store Connect export, and App Store validation"))
        XCTAssertNotNil(script.range(of: "bundle id: com.despia.buysellai"))
        XCTAssertNotNil(script.range(of: "M10_DEVELOPMENT_TEAM"))
        XCTAssertNotNil(script.range(of: "IOS_DISTRIBUTION_CERTIFICATE_BASE64"))
        XCTAssertNotNil(script.range(of: "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"))
        XCTAssertNotNil(script.range(of: "IOS_PROVISIONING_PROFILE_BASE64"))
        XCTAssertNotNil(script.range(of: "ASC_API_KEY_ID"))
        XCTAssertNotNil(script.range(of: "ASC_API_ISSUER_ID"))
        XCTAssertNotNil(script.range(of: "ASC_API_PRIVATE_KEY"))
        XCTAssertNotNil(script.range(of: "IOS_KEYCHAIN_PASSWORD"))
        XCTAssertNotNil(script.range(of: #"printf 'present: %s\n' "$name""#))
        XCTAssertNotNil(script.range(of: #"[[ -n "${!name:-}" ]]"#))
        XCTAssertNil(script.range(of: #"printf '%s\n' "${!name"#))
    }

    func testCloudCredentialScriptHasPendingAndStrictModes() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_app_store_cloud_credentials.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_APP_STORE_CREDENTIALS"))
        XCTAssertNotNil(script.range(of: "App Store cloud credential check pending"))
        XCTAssertNotNil(script.range(of: "App Store cloud credential check failed"))
        XCTAssertNotNil(script.range(of: "App Store cloud credential check passed"))
        XCTAssertNotNil(script.range(of: "allow_missing"))
        XCTAssertNotNil(script.range(of: "exit 0"))
        XCTAssertNotNil(script.range(of: "exit 1"))
    }

    func testAppStoreWorkflowRunsAndUploadsCloudCredentialCheck() throws {
        let workflow = try String(contentsOf: projectURL(".github/workflows/app-store-preflight.yml"), encoding: .utf8)

        XCTAssertNotNil(workflow.range(of: "Check App Store cloud credentials"))
        XCTAssertNotNil(workflow.range(of: "ALLOW_MISSING_APP_STORE_CREDENTIALS=1"))
        XCTAssertNotNil(workflow.range(of: "Scripts/verify_app_store_cloud_credentials.sh | tee /tmp/buysell-app-store-cloud-credentials.log"))
        XCTAssertNotNil(workflow.range(of: "/tmp/buysell-app-store-cloud-credentials.log"))
    }

    func testDocsNameTheHostedCredentialChecklist() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        for text in [readme, m10] {
            XCTAssertNotNil(text.range(of: "Scripts/verify_app_store_cloud_credentials.sh"))
            XCTAssertNotNil(text.range(of: "/tmp/buysell-app-store-cloud-credentials.log"))
            XCTAssertNotNil(text.range(of: "allow_missing_credentials=false"))
        }
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
