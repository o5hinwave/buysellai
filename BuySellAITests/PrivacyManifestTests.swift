import Foundation
import XCTest

final class PrivacyManifestTests: XCTestCase {
    func testPrivacyManifestDeclaresNoTracking() throws {
        let manifest = try privacyManifest()

        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(manifest["NSPrivacyTrackingDomains"] as? [String], [])
    }

    func testPrivacyManifestDeclaresCollectedDataForAppFunctionalityOnly() throws {
        let manifest = try privacyManifest()
        let dataTypes = try XCTUnwrap(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let expectedTypes: Set<String> = [
            "NSPrivacyCollectedDataTypeEmailAddress",
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypePhotosorVideos",
            "NSPrivacyCollectedDataTypeOtherUserContent"
        ]

        XCTAssertEqual(Set(dataTypes.compactMap { $0["NSPrivacyCollectedDataType"] as? String }), expectedTypes)

        for dataType in dataTypes {
            XCTAssertEqual(dataType["NSPrivacyCollectedDataTypeLinked"] as? Bool, true)
            XCTAssertEqual(dataType["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
            XCTAssertEqual(
                dataType["NSPrivacyCollectedDataTypePurposes"] as? [String],
                ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]
            )
        }
    }

    func testPrivacyManifestDeclaresAppOnlyUserDefaultsReason() throws {
        let manifest = try privacyManifest()
        let accessedTypes = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = try XCTUnwrap(accessedTypes.first { entry in
            entry["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })

        XCTAssertEqual(accessedTypes.count, 1)
        XCTAssertEqual(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    func testUserDefaultsUsageHasRequiredReasonManifest() throws {
        let appSource = try appSwiftFiles()
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        let manifest = try privacyManifest()
        let accessedTypes = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])

        XCTAssertNotNil(appSource.range(of: #"\bUserDefaults\b"#, options: .regularExpression))
        XCTAssertTrue(accessedTypes.contains { entry in
            entry["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })
    }

    func testPrivacyManifestIsNotExcludedFromAppTarget() throws {
        let project = try String(contentsOf: projectURL("BuySellAI.xcodeproj/project.pbxproj"), encoding: .utf8)
        let exceptionsStart = try XCTUnwrap(project.range(of: "/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */"))
        let exceptionsEnd = try XCTUnwrap(project.range(of: "/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */"))
        let exceptions = String(project[exceptionsStart.upperBound..<exceptionsEnd.lowerBound])

        XCTAssertNil(exceptions.range(of: "PrivacyInfo.xcprivacy"))
    }

    private func privacyManifest(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let url = projectURL("BuySellAI/PrivacyInfo.xcprivacy")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), file: file, line: line)

        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any], file: file, line: line)
    }

    private func appSwiftFiles() throws -> [URL] {
        let root = projectURL("BuySellAI")
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else { return nil }
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
