import Foundation
import XCTest

final class SigningCapabilityTests: XCTestCase {
    func testAppEntitlementsEnableSignInWithAppleOnly() throws {
        let entitlements = try plistDictionary(at: projectURL("BuySellAI/BuySellAI.entitlements"))

        XCTAssertEqual(Set(entitlements.keys), ["com.apple.developer.applesignin"])
        XCTAssertEqual(entitlements["com.apple.developer.applesignin"] as? [String], ["Default"])
    }

    func testAppTargetBuildConfigurationsUseEntitlementsAndAutomaticSigning() throws {
        let project = try projectFile()
        let appConfigurations = try buildConfigurations(forBundleID: "com.despia.buysellai", in: project)

        XCTAssertEqual(Set(appConfigurations.keys), ["Debug", "Release"])

        for configuration in appConfigurations.values {
            XCTAssertEqual(setting("CODE_SIGN_ENTITLEMENTS", in: configuration), "BuySellAI/BuySellAI.entitlements")
            XCTAssertEqual(setting("CODE_SIGN_STYLE", in: configuration), "Automatic")
            XCTAssertEqual(setting("INFOPLIST_FILE", in: configuration), "BuySellAI/Info.plist")
            XCTAssertEqual(setting("PRODUCT_BUNDLE_IDENTIFIER", in: configuration), "com.despia.buysellai")
            XCTAssertEqual(setting("DEVELOPMENT_TEAM", in: configuration), "ZVFG6KC7KA")
            XCTAssertEqual(setting("SUPPORTED_PLATFORMS", in: configuration), "iphoneos iphonesimulator")
            XCTAssertEqual(setting("TARGETED_DEVICE_FAMILY", in: configuration), "1,2")
        }
    }

    func testOnlyAppTargetReferencesAppEntitlements() throws {
        let project = try projectFile()
        let entitlementsReferences = project.components(separatedBy: "CODE_SIGN_ENTITLEMENTS = BuySellAI/BuySellAI.entitlements;").count - 1

        XCTAssertEqual(entitlementsReferences, 2)
    }

    func testSignedSubmitGatesDocumentApplePortalAndExternalEvidenceBlockers() throws {
        let project = try projectFile()
        let appConfigurations = try buildConfigurations(forBundleID: "com.despia.buysellai", in: project)
        let teamIDs = Set(appConfigurations.values.compactMap { setting("DEVELOPMENT_TEAM", in: $0) })
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)

        XCTAssertEqual(teamIDs, ["ZVFG6KC7KA"])
        XCTAssertNotNil(readme.range(of: "Apple Developer account state: team `RHODES MCALLEN COONS COONS` (`ZVFG6KC7KA`) is selected in the Xcode project for Bundle ID `com.despia.buysellai`"))
        XCTAssertNotNil(readme.range(of: "The Apple Developer portal has Sign in with Apple enabled for the primary App ID and Services ID `com.despia.buysellai.signin` configured for domain `czuoebqjajupghivqkch.supabase.co`"))
        XCTAssertNotNil(readme.range(of: "A signed archive, App Store Connect IPA export, App Store Connect validation, App Store Connect legal/account-owner confirmation, and Instruments pass are blocked until App Store Connect API-key credentials, confirmed account-owner/product-page metadata, Apple signing assets, and trusted physical hardware are available"))
        XCTAssertNotNil(readme.range(of: "real-device acceptance pass remains blocked until the acceptance evidence table is recorded"))
    }

    private func buildConfigurations(forBundleID bundleID: String, in project: String) throws -> [String: String] {
        let regex = try NSRegularExpression(
            pattern: #"buildSettings = \{(.*?)\};\s*name = (Debug|Release);"#,
            options: [.dotMatchesLineSeparators]
        )
        let range = NSRange(project.startIndex..<project.endIndex, in: project)
        let matches = regex.matches(in: project, range: range)

        return matches.reduce(into: [String: String]()) { result, match in
            guard
                let settingsRange = Range(match.range(at: 1), in: project),
                let nameRange = Range(match.range(at: 2), in: project)
            else {
                return
            }
            let settings = String(project[settingsRange])
            guard setting("PRODUCT_BUNDLE_IDENTIFIER", in: settings) == bundleID else {
                return
            }
            result[String(project[nameRange])] = settings
        }
    }

    private func setting(_ name: String, in settings: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: #"\b\#(name) = ([^;]+);"#),
            let match = regex.firstMatch(in: settings, range: NSRange(settings.startIndex..<settings.endIndex, in: settings)),
            let valueRange = Range(match.range(at: 1), in: settings)
        else {
            return nil
        }
        return settings[valueRange]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: #"""#))
    }

    private func projectFile() throws -> String {
        try String(contentsOf: projectURL("BuySellAI.xcodeproj/project.pbxproj"), encoding: .utf8)
    }

    private func plistDictionary(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
