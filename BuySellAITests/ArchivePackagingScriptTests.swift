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
        XCTAssertNotNil(script.range(of: "CFBundleIdentifier"))
        XCTAssertNotNil(script.range(of: "bundle id:"))
        XCTAssertNotNil(script.range(of: "CFBundleShortVersionString"))
        XCTAssertNotNil(script.range(of: "CFBundleVersion"))
        XCTAssertNotNil(script.range(of: "release build:"))
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
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
