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

    func testRealDeviceAcceptanceEvidenceScriptRequiresMetadataAndPromptRows() throws {
        let scriptURL = projectURL("Scripts/verify_m10_real_device_acceptance.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "ALLOW_PENDING_ACCEPTANCE"))
        XCTAssertNotNil(script.range(of: "expected exactly 15 real-device acceptance rows"))
        XCTAssertNotNil(script.range(of: "M10 real-device acceptance pending"))
        XCTAssertNotNil(script.range(of: "M10 real-device acceptance evidence passed"))
        XCTAssertNotNil(script.range(of: "duration_ms_from_text"))
        XCTAssertNotNil(script.range(of: "require_evidence_duration_at_most"))
        XCTAssertNotNil(script.range(of: "require_evidence_terms"))
        XCTAssertNotNil(script.range(of: "marketplace list, payouts, Best, and Lowest proof"))
        XCTAssertNotNil(script.range(of: "clipboard listing text with no leading whitespace or preamble proof"))
        XCTAssertNotNil(script.range(of: "VoiceOver full flow proof"))
        XCTAssertNotNil(script.range(of: "Airplane mode offline toast and retry proof"))
        XCTAssertNotNil(script.range(of: "Sign in with Apple one-time migration and duplicate proof"))
        XCTAssertNotNil(script.range(of: "A01\" \"1000\" \"cold-launch"))
        XCTAssertNotNil(script.range(of: "A02\" \"400\" \"camera-ready"))
        XCTAssertNotNil(script.range(of: "A03\" \"300\" \"capture-to-result"))
        XCTAssertNotNil(script.range(of: "Device model"))
        XCTAssertNotNil(script.range(of: "iOS version"))
        XCTAssertNotNil(script.range(of: "Backend project"))
        XCTAssertNotNil(script.range(of: "Release build"))
        XCTAssertNotNil(script.range(of: "App Store validation"))
        XCTAssertNotNil(script.range(of: "A01"))
        XCTAssertNotNil(script.range(of: "A15"))
    }

    func testRealDeviceAcceptanceDocsRouteManualEvidenceThroughScript() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md"))
        XCTAssertNotNil(readme.range(of: "ALLOW_PENDING_ACCEPTANCE=1"))
        XCTAssertNotNil(readme.range(of: "generic \"passed\" notes are intentionally rejected"))
        XCTAssertNotNil(m10.range(of: "Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md"))
        XCTAssertNotNil(m10.range(of: "ALLOW_PENDING_ACCEPTANCE=1"))
        XCTAssertNotNil(m10.range(of: "Record a passing 15-item real-device acceptance evidence table"))
        XCTAssertNotNil(m10.range(of: "The verifier checks for these proof terms"))
        XCTAssertNotNil(m10.range(of: "A05 `platform`, `payout`, `best`, `lowest`"))
        XCTAssertNotNil(m10.range(of: "A06 `clipboard`, `listing text`, `no leading whitespace`, `no preamble`"))
        XCTAssertNotNil(m10.range(of: "A13 `voiceover`, `home`, `camera`, `result`, `picker`, `listing`, `copy`"))
        XCTAssertNotNil(m10.range(of: "A14 `airplane`, `offline`, `you're offline. reconnect and try again.`, `retry`"))
        XCTAssertNotNil(m10.range(of: "A15 `sign in with apple`, `migration`, `once`, `duplicate`"))
    }

    func testRealDeviceAcceptanceDocsContainExactlyFifteenPromptRows() throws {
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)
        let expectedIDs = (1...15).map { String(format: "A%02d", $0) }

        XCTAssertEqual(acceptanceIDs(in: m10), expectedIDs)
        XCTAssertNotNil(m10.range(of: "history persists (guest via SwiftData; signed-in via server)"))
        XCTAssertNotNil(m10.range(of: "VoiceOver can complete Home -> Camera -> Result -> Picker -> Listing -> Copy"))
        XCTAssertNil(m10.range(of: "Guest history persists after killing"))
        XCTAssertNil(m10.range(of: "Signed-in history sync persists after killing"))
    }

    func testRealDeviceAcceptanceDocsStartPendingUntilDeviceEvidenceIsRecorded() throws {
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)
        let pendingRows = m10.components(separatedBy: "| Pending | TBD |").count - 1

        XCTAssertEqual(pendingRows, 15)
        XCTAssertNotNil(m10.range(of: "| Device model | TBD |"))
        XCTAssertNotNil(m10.range(of: "| Signed archive | TBD |"))
        XCTAssertNotNil(m10.range(of: "| App Store validation | TBD |"))
    }

    func testRealDeviceAcceptanceVerifierParsesTimingEvidenceInMillisecondsOrSeconds() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_real_device_acceptance.sh"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "ms|millisecond|milliseconds"))
        XCTAssertNotNil(script.range(of: "s|sec|secs|second|seconds"))
        XCTAssertNotNil(script.range(of: #"value \* 1000"#, options: .regularExpression))
        XCTAssertNotNil(script.range(of: "evidence must include a measured $label duration in ms or seconds"))
        XCTAssertNotNil(script.range(of: "expected <= ${limit_ms} ms"))
        XCTAssertNotNil(m10.range(of: "For A01-A03, include the measured duration in `ms` or seconds"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    private func acceptanceIDs(in markdown: String) -> [String] {
        markdown
            .split(separator: "\n")
            .compactMap { line -> String? in
                let columns = line.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard columns.count >= 5, columns[1].range(of: #"^A[0-9]{2}$"#, options: .regularExpression) != nil else {
                    return nil
                }
                return columns[1]
            }
    }
}
