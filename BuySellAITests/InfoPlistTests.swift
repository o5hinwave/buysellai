import Foundation
import XCTest

final class InfoPlistTests: XCTestCase {
    func testIPhoneSupportsPortraitOnly() throws {
        let plist = try projectInfoPlist()
        let orientations = try XCTUnwrap(plist["UISupportedInterfaceOrientations"] as? [String])

        XCTAssertEqual(orientations, ["UIInterfaceOrientationPortrait"])
    }

    func testIPadSupportsAllOrientations() throws {
        let plist = try projectInfoPlist()
        let orientations = try XCTUnwrap(plist["UISupportedInterfaceOrientations~ipad"] as? [String])

        XCTAssertEqual(
            orientations,
            [
                "UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationPortraitUpsideDown",
                "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight"
            ]
        )
    }

    func testAppDeclaresRequiredRuntimeMetadata() throws {
        let plist = try projectInfoPlist()

        XCTAssertEqual(
            plist["NSCameraUsageDescription"] as? String,
            "BuySell uses your camera to snap photos of items you want to sell."
        )
        XCTAssertEqual(plist["ITSAppUsesNonExemptEncryption"] as? Bool, false)
        XCTAssertEqual(plist["UIRequiresFullScreen"] as? Bool, false)
        XCTAssertEqual(plist["UILaunchStoryboardName"] as? String, "LaunchScreen")
    }

    func testProjectTargetsIOSSeventeenMinimum() throws {
        let project = try String(contentsOf: projectURL("BuySellAI.xcodeproj/project.pbxproj"), encoding: .utf8)
        let deploymentTargets = try buildSettingValues(named: "IPHONEOS_DEPLOYMENT_TARGET", in: project)

        XCTAssertFalse(deploymentTargets.isEmpty)
        XCTAssertEqual(Set(deploymentTargets), ["17.0"])
    }

    func testRegistersStaticBrandFontVariants() throws {
        let plist = try projectInfoPlist()
        let appFonts = try XCTUnwrap(plist["UIAppFonts"] as? [String])

        XCTAssertEqual(
            appFonts,
            [
                "SpaceGrotesk-Regular.ttf",
                "SpaceGrotesk-Medium.ttf",
                "SpaceGrotesk-SemiBold.ttf",
                "SpaceGrotesk-Bold.ttf",
                "Inter-Regular.ttf",
                "Inter-Medium.ttf",
                "Inter-SemiBold.ttf",
                "Inter-Bold.ttf"
            ]
        )

        for font in appFonts {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: projectURL("BuySellAI/Resources/Fonts/\(font)").path),
                "Missing registered font file \(font)"
            )
        }
    }

    func testLaunchScreenUsesFixedWhiteBrandWordmark() throws {
        let storyboard = try String(
            contentsOf: projectURL("BuySellAI/Resources/Base.lproj/LaunchScreen.storyboard"),
            encoding: .utf8
        )

        XCTAssertNil(storyboard.range(of: "systemBackgroundColor"))
        XCTAssertNil(storyboard.range(of: "activityIndicatorView"))
        XCTAssertNotNil(storyboard.range(of: #"text="BuySell""#))
        XCTAssertNotNil(storyboard.range(of: #"text=".""#))
        XCTAssertNotNil(storyboard.range(of: #"red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB""#))
        XCTAssertNotNil(storyboard.range(of: #"red="0.07058823529" green="0.07058823529" blue="0.07058823529""#))
        XCTAssertNotNil(storyboard.range(of: #"red="1" green="0.47843137250000001" blue="0.14901960780000001""#))
    }

    func testSwiftUISplashUsesLaunchColorTokens() throws {
        let appRouter = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let designTokens = try String(contentsOf: projectURL("BuySellAI/Design/DesignTokens.swift"), encoding: .utf8)

        XCTAssertNotNil(appRouter.range(of: "Color.brand.launchBackground"))
        XCTAssertNotNil(appRouter.range(of: "Color.brand.launchForeground"))
        XCTAssertNotNil(appRouter.range(of: "Color.brand.launchPrimary"))
        XCTAssertNotNil(designTokens.range(of: "static let launchBackground = Color(hex: 0xFFFFFF)"))
        XCTAssertNotNil(designTokens.range(of: "static let launchForeground = Color(hex: 0x121212)"))
        XCTAssertNotNil(designTokens.range(of: "static let launchPrimary = Color(hex: 0xFF7A26)"))
    }

    private func projectInfoPlist(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let candidates = [projectURL("BuySellAI/Info.plist")]

        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            XCTFail("Missing BuySellAI/Info.plist", file: file, line: line)
            return [:]
        }

        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any], file: file, line: line)
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    private func buildSettingValues(named setting: String, in project: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: #"\b\#(setting) = ([^;]+);"#)
        let range = NSRange(project.startIndex..<project.endIndex, in: project)
        return regex.matches(in: project, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: project) else { return nil }
            return project[valueRange].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
