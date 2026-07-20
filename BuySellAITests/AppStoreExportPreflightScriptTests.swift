import Foundation
import XCTest

final class AppStoreExportPreflightScriptTests: XCTestCase {
    func testAppStoreExportPreflightChecksReleaseSigningAndEntitlements() throws {
        let scriptURL = projectURL("Scripts/preflight_m10_app_store_export.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "xcodebuild -showBuildSettings"))
        XCTAssertNotNil(script.range(of: "-scheme BuySellAI"))
        XCTAssertNotNil(script.range(of: "-configuration Release"))
        XCTAssertNotNil(script.range(of: #"setting PRODUCT_BUNDLE_IDENTIFIER"#))
        XCTAssertNotNil(script.range(of: #"setting CODE_SIGN_STYLE"#))
        XCTAssertNotNil(script.range(of: #"setting CODE_SIGN_ENTITLEMENTS"#))
        XCTAssertNotNil(script.range(of: #"setting DEVELOPMENT_TEAM"#))
        XCTAssertNotNil(script.range(of: "DEVELOPMENT_TEAM is unset"))
        XCTAssertNotNil(script.range(of: "M10_DEVELOPMENT_TEAM"))
        XCTAssertNotNil(script.range(of: "M10_XCODEBUILD_SETTINGS_TIMEOUT"))
        XCTAssertNotNil(script.range(of: "settings_timeout_seconds"))
        XCTAssertNotNil(script.range(of: "project_development_team_is_configured"))
        XCTAssertNotNil(script.range(of: "print_missing_team_pending"))
        XCTAssertNotNil(script.range(of: "show_release_build_settings"))
        XCTAssertNotNil(script.range(of: "timed out after"))
        XCTAssertNotNil(script.range(of: "M10_APP_STORE_EXPORT_SNAPSHOT_ROOT"))
        XCTAssertNotNil(script.range(of: "prepare_snapshot"))
        XCTAssertNotNil(script.range(of: #"M10_APP_STORE_EXPORT_SNAPSHOT_ROOT must be under /tmp"#))
        XCTAssertNotNil(script.range(of: #"M10_APP_STORE_EXPORT_SNAPSHOT_ROOT must not point at the source checkout"#))
        XCTAssertNotNil(script.range(of: #"rsync -a "${source_root}/${entry}" "$target/""#))
        XCTAssertNotNil(script.range(of: #"project_path="${work_root}/BuySellAI.xcodeproj""#))
        XCTAssertNotNil(script.range(of: "team_build_setting"))
        XCTAssertNotNil(script.range(of: #"DEVELOPMENT_TEAM=${m10_development_team}"#))
        XCTAssertNotNil(script.range(of: "Set M10_DEVELOPMENT_TEAM"))
        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_TEAM"))
        XCTAssertNotNil(script.range(of: "com.apple.developer.applesignin"))
        XCTAssertNotNil(script.range(of: "signed_sign_in_with_apple"))
        XCTAssertNotNil(script.range(of: "exported_sign_in_with_apple"))
        XCTAssertNotNil(script.range(of: "sign in with apple:"))
    }

    func testAppStoreExportPreflightUsesAppStoreConnectExportOptions() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_app_store_export.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "xcodebuild archive"))
        XCTAssertNotNil(script.range(of: "xcodebuild -exportArchive"))
        XCTAssertNotNil(script.range(of: "-destination 'generic/platform=iOS'"))
        XCTAssertNotNil(script.range(of: "-allowProvisioningUpdates"))
        XCTAssertNotNil(script.range(of: #"${team_build_setting:+"$team_build_setting"}"#))
        XCTAssertNotNil(script.range(of: "<key>method</key>"))
        XCTAssertNotNil(script.range(of: "<string>app-store-connect</string>"))
        XCTAssertNotNil(script.range(of: "<key>signingStyle</key>"))
        XCTAssertNotNil(script.range(of: "<string>automatic</string>"))
        XCTAssertNotNil(script.range(of: "<key>teamID</key>"))
        XCTAssertNil(script.range(of: "CODE_SIGNING_ALLOWED=NO"))
        XCTAssertNil(script.range(of: "CODE_SIGNING_REQUIRED=NO"))
    }

    func testAppStoreExportPreflightChecksExportedIPAContents() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_app_store_export.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "find \"$export_path\""))
        XCTAssertNotNil(script.range(of: "'*.ipa'"))
        XCTAssertNotNil(script.range(of: "Payload/BuySellAI.app/Info.plist"))
        XCTAssertNotNil(script.range(of: "Payload/BuySellAI.app/PrivacyInfo.xcprivacy"))
        XCTAssertNotNil(script.range(of: "Payload/BuySellAI.app/BuySellAI"))
        XCTAssertNotNil(script.range(of: "unzip -q \"$ipa_path\""))
        XCTAssertNotNil(script.range(of: "exported_bundle_id"))
        XCTAssertNotNil(script.range(of: "bundle id:"))
        XCTAssertNotNil(script.range(of: "snapshot root:"))
        XCTAssertNotNil(script.range(of: "codesign -d --entitlements :- \"$exported_app_path\""))
        XCTAssertNotNil(script.range(of: "CFBundleShortVersionString"))
        XCTAssertNotNil(script.range(of: "CFBundleVersion"))
        XCTAssertNotNil(script.range(of: "release build:"))
        XCTAssertNotNil(script.range(of: "M10 App Store export preflight passed"))
    }

    func testAcceptanceDocsRouteAppStoreExportThroughPreflight() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/preflight_m10_app_store_export.sh"))
        XCTAssertNotNil(readme.range(of: "M10_APP_STORE_EXPORT_SNAPSHOT_ROOT=/tmp/buysell-m10-appstore-export-worktree"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-submit-readiness-export-preflight.log"))
        XCTAssertNotNil(m10.range(of: "Scripts/preflight_m10_app_store_export.sh"))
        XCTAssertNotNil(m10.range(of: "M10_APP_STORE_EXPORT_SNAPSHOT_ROOT=/tmp/buysell-m10-appstore-export-worktree"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-export-preflight.log"))
        XCTAssertNotNil(m10.range(of: "ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_app_store_export.sh"))
        XCTAssertNotNil(m10.range(of: "App Store Connect IPA"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
