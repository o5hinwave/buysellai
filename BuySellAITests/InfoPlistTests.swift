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
}
