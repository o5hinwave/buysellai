import Foundation
import XCTest

final class AppStoreValidationPreflightScriptTests: XCTestCase {
    func testAppStoreValidationPreflightChecksExportedIPAContents() throws {
        let scriptURL = projectURL("Scripts/preflight_m10_app_store_validate.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "Payload/BuySellAI.app/Info.plist"))
        XCTAssertNotNil(script.range(of: "Payload/BuySellAI.app/PrivacyInfo.xcprivacy"))
        XCTAssertNotNil(script.range(of: "Payload/BuySellAI.app/BuySellAI"))
        XCTAssertNotNil(script.range(of: "unzip -q \"$ipa_path\""))
        XCTAssertNotNil(script.range(of: "codesign -d --entitlements :- \"$ipa_app_path\""))
        XCTAssertNotNil(script.range(of: "com.apple.developer.applesignin"))
        XCTAssertNotNil(script.range(of: "sign in with apple:"))
        XCTAssertNotNil(script.range(of: "CFBundleIdentifier"))
        XCTAssertNotNil(script.range(of: "ipa_bundle_id"))
        XCTAssertNotNil(script.range(of: "bundle id:"))
        XCTAssertNotNil(script.range(of: "CFBundleShortVersionString"))
        XCTAssertNotNil(script.range(of: "CFBundleVersion"))
        XCTAssertNotNil(script.range(of: "NSCameraUsageDescription"))
        XCTAssertNotNil(script.range(of: "com.rhodes.buysellai"))
        XCTAssertNotNil(script.range(of: "release build:"))
    }

    func testAppStoreValidationPreflightChecksPrivacyManifestContents() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_app_store_validate.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "require_privacy_manifest_values"))
        XCTAssertNotNil(script.range(of: "NSPrivacyTracking"))
        XCTAssertNotNil(script.range(of: "NSPrivacyTrackingDomains"))
        XCTAssertNotNil(script.range(of: "privacy manifest must declare exactly 4 collected data types"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypeEmailAddress"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypeUserID"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypePhotosorVideos"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypeOtherUserContent"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypePurposeAppFunctionality"))
        XCTAssertNotNil(script.range(of: "NSPrivacyAccessedAPICategoryUserDefaults"))
        XCTAssertNotNil(script.range(of: "CA92.1"))
    }

    func testAppStoreValidationPreflightUsesAltoolValidationWithAPIKeyAuth() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_app_store_validate.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "xcrun altool --validate-app"))
        XCTAssertNotNil(script.range(of: "-t ios"))
        XCTAssertNotNil(script.range(of: "--apiKey \"$api_key_id\""))
        XCTAssertNotNil(script.range(of: "--apiIssuer \"$api_issuer_id\""))
        XCTAssertNotNil(script.range(of: "--output-format json"))
        XCTAssertNotNil(script.range(of: "ASC_API_KEY_ID"))
        XCTAssertNotNil(script.range(of: "ASC_API_ISSUER_ID"))
        XCTAssertNotNil(script.range(of: "ASC_API_PRIVATE_KEYS_DIR"))
        XCTAssertNotNil(script.range(of: "API_PRIVATE_KEYS_DIR"))
    }

    func testAppStoreValidationPreflightHasPendingModeForMissingExternalState() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_app_store_validate.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_ASC"))
        XCTAssertNotNil(script.range(of: "missing IPA"))
        XCTAssertNotNil(script.range(of: "ASC_API_KEY_ID is unset"))
        XCTAssertNotNil(script.range(of: "ASC_API_ISSUER_ID is unset"))
        XCTAssertNotNil(script.range(of: "M10 App Store validation preflight pending"))
        XCTAssertNotNil(script.range(of: "M10 App Store validation preflight passed"))
    }

    func testAcceptanceDocsRouteAppStoreValidationThroughPreflight() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/preflight_m10_app_store_validate.sh"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-submit-readiness-app-store-validation-preflight.log"))
        XCTAssertNotNil(m10.range(of: "Scripts/preflight_m10_app_store_validate.sh"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-app-store-validation-preflight.log"))
        XCTAssertNotNil(m10.range(of: "ALLOW_MISSING_ASC=1 bash Scripts/preflight_m10_app_store_validate.sh"))
        XCTAssertNotNil(m10.range(of: "App Store Connect validation"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
