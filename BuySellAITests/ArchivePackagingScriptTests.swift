import Foundation
import XCTest

final class ArchivePackagingScriptTests: XCTestCase {
    func testLocalArchiveVerifierEnforcesPromptPackageGates() throws {
        let scriptURL = projectURL("Scripts/verify_m10_local_archive.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "xcodebuild archive"))
        XCTAssertNotNil(script.range(of: "CODE_SIGNING_ALLOWED=NO"))
        XCTAssertNotNil(script.range(of: "CODE_SIGNING_REQUIRED=NO"))
        XCTAssertNotNil(script.range(of: "CODE_SIGN_IDENTITY=\"\""))
        XCTAssertNotNil(script.range(of: "MAX_APP_SIZE_KB:-20480"))
        XCTAssertNotNil(script.range(of: "PrivacyInfo.xcprivacy"))
        XCTAssertNotNil(script.range(of: "plutil -lint \"$privacy_manifest\""))
        XCTAssertNotNil(script.range(of: "AppIcon.appiconset/Contents.json"))
        XCTAssertNotNil(script.range(of: "AppIcon.appiconset/AppIcon-1024.png"))
        XCTAssertNotNil(script.range(of: "AppIcon60x60@2x.png"))
        XCTAssertNotNil(script.range(of: "AppIcon76x76@2x~ipad.png"))
        XCTAssertNotNil(script.range(of: "sips_property"))
        XCTAssertNotNil(script.range(of: "require_png_dimensions \"$app_icon_source\" 1024 1024 \"source App Store icon\""))
        XCTAssertNotNil(script.range(of: "require_png_dimensions \"$iphone_icon\" 120 120 \"archived iPhone app icon\""))
        XCTAssertNotNil(script.range(of: "require_png_dimensions \"$ipad_icon\" 152 152 \"archived iPad app icon\""))
        XCTAssertNotNil(script.range(of: "hasAlpha"))
        XCTAssertNotNil(script.range(of: "AppIcon asset catalog must declare a 1024x1024 iOS icon"))
        XCTAssertNotNil(script.range(of: "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName"))
        XCTAssertNotNil(script.range(of: "CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconName"))
        XCTAssertNotNil(script.range(of: "require_privacy_manifest_values \"$privacy_manifest\""))
        XCTAssertNotNil(script.range(of: "privacy manifest must declare NSPrivacyTracking=false"))
        XCTAssertNotNil(script.range(of: "privacy manifest must declare exactly 4 collected data types"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypeEmailAddress"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypeUserID"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypePhotosorVideos"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypeOtherUserContent"))
        XCTAssertNotNil(script.range(of: "NSPrivacyCollectedDataTypePurposeAppFunctionality"))
        XCTAssertNotNil(script.range(of: "NSPrivacyAccessedAPICategoryUserDefaults"))
        XCTAssertNotNil(script.range(of: "CA92.1"))
        XCTAssertNotNil(script.range(of: "CFBundleIdentifier"))
        XCTAssertNotNil(script.range(of: "bundle id:"))
        XCTAssertNotNil(script.range(of: "CFBundleShortVersionString"))
        XCTAssertNotNil(script.range(of: "CFBundleVersion"))
        XCTAssertNotNil(script.range(of: "release build:"))
        XCTAssertNotNil(script.range(of: "app icon: AppIcon 1024x1024 source, 120x120 iPhone, 152x152 iPad"))
        XCTAssertNotNil(script.range(of: "NSCameraUsageDescription"))
        XCTAssertNotNil(script.range(of: "ITSAppUsesNonExemptEncryption"))
        XCTAssertNotNil(script.range(of: "NSPhotoLibraryUsageDescription"))
        XCTAssertNotNil(script.range(of: "NSPhotoLibraryAddUsageDescription"))
    }

    func testAcceptanceDocsRouteNoSignArchiveThroughLocalVerifier() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_local_archive.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_local_archive.sh"))
        XCTAssertNotNil(m10.range(of: "Binary-size check: archived app bundle stays under `20 MB`."))
        XCTAssertNotNil(m10.range(of: "App icon check: source App Store icon is a 1024x1024 non-alpha PNG and the archive contains iPhone/iPad icon PNGs."))
        XCTAssertNotNil(m10.range(of: "Privacy manifest content check"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
