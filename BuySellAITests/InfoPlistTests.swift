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

    private func projectInfoPlist(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("BuySellAI/Info.plist"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("BuySellAI/Info.plist")
        ]

        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            XCTFail("Missing BuySellAI/Info.plist", file: file, line: line)
            return [:]
        }

        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any], file: file, line: line)
    }
}
