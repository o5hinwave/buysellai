import Foundation
import XCTest

final class RealDevicePreflightScriptTests: XCTestCase {
    func testRealDevicePreflightDiscoversConnectedDeviceWithDevicectlJSON() throws {
        let scriptURL = projectURL("Scripts/preflight_m10_real_device.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "xcrun devicectl list devices"))
        XCTAssertNotNil(script.range(of: "--json-output"))
        XCTAssertNotNil(script.range(of: "plutil -convert xml1"))
        XCTAssertNotNil(script.range(of: #"DEVICE_ID"#))
        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_DEVICE"))
        XCTAssertNotNil(script.range(of: "no connected iPhone or iPad"))
    }

    func testRealDevicePreflightRequiresReleaseSigningBeforeBuild() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_real_device.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "xcodebuild -showBuildSettings"))
        XCTAssertNotNil(script.range(of: "-configuration Release"))
        XCTAssertNotNil(script.range(of: #"setting PRODUCT_BUNDLE_IDENTIFIER"#))
        XCTAssertNotNil(script.range(of: #"setting CODE_SIGN_STYLE"#))
        XCTAssertNotNil(script.range(of: #"setting CODE_SIGN_ENTITLEMENTS"#))
        XCTAssertNotNil(script.range(of: #"setting DEVELOPMENT_TEAM"#))
        XCTAssertNotNil(script.range(of: "DEVELOPMENT_TEAM is unset"))
    }

    func testRealDevicePreflightBuildsReleaseForPhysicalDevice() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_real_device.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "xcodebuild build"))
        XCTAssertNotNil(script.range(of: #"-destination "id=${device_identifier}""#))
        XCTAssertNotNil(script.range(of: "-allowProvisioningUpdates"))
        XCTAssertNotNil(script.range(of: "M10 real-device preflight passed"))
        XCTAssertNil(script.range(of: "platform=iOS Simulator"))
        XCTAssertNil(script.range(of: "CODE_SIGNING_ALLOWED=NO"))
    }

    func testAcceptanceDocsRouteRealDeviceAcceptanceThroughPreflight() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/preflight_m10_real_device.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/preflight_m10_real_device.sh"))
        XCTAssertNotNil(m10.range(of: "ALLOW_MISSING_DEVICE=1"))
        XCTAssertNotNil(m10.range(of: "trusted iPhone or iPad with Developer Mode enabled"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
