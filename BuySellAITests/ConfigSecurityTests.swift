import Foundation
import XCTest

final class ConfigSecurityTests: XCTestCase {
    func testConfigExampleOnlyContainsPublicSupabaseFields() throws {
        let plist = try plistDictionary(at: projectURL("BuySellAI/App/Config.plist.example"))

        XCTAssertEqual(Set(plist.keys), ["SUPABASE_URL", "SUPABASE_ANON_KEY"])
    }

    func testRuntimeConfigPlistIsGitIgnored() throws {
        let gitignore = try String(contentsOf: projectURL(".gitignore"), encoding: .utf8)
        let ignoredPaths = Set(
            gitignore
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.isEmpty == false && $0.hasPrefix("#") == false }
        )

        XCTAssertTrue(ignoredPaths.contains("BuySellAI/App/Config.plist"))
    }

    func testConfigExampleIsExcludedFromSynchronizedAppTarget() throws {
        let project = try String(contentsOf: projectURL("BuySellAI.xcodeproj/project.pbxproj"), encoding: .utf8)
        let exceptionsStart = try XCTUnwrap(project.range(of: "/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */"))
        let exceptionsEnd = try XCTUnwrap(project.range(of: "/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */"))
        let exceptions = String(project[exceptionsStart.upperBound..<exceptionsEnd.lowerBound])

        XCTAssertNotNil(exceptions.range(of: #"Exceptions for "BuySellAI" folder in "BuySellAI" target"#))
        XCTAssertNotNil(exceptions.range(of: "membershipExceptions = ("))
        XCTAssertNotNil(exceptions.range(of: "App/Config.plist.example,"))
        XCTAssertNotNil(exceptions.range(of: #"target = [A-Z0-9]+ /\* BuySellAI \*/;"#, options: .regularExpression))
        XCTAssertNil(project.range(of: "Config.plist.example in Resources"))
    }

    func testBundledAppTextFilesDoNotContainAIProviderSecrets() throws {
        let appURL = projectURL("BuySellAI")
        let textExtensions: Set<String> = ["json", "plist", "storyboard", "strings", "swift"]
        let secretPatterns = [
            #"AIza[0-9A-Za-z_-]{20,}"#,
            #"AQ\.[0-9A-Za-z_-]{20,}"#,
            #"sk-[0-9A-Za-z_-]{20,}"#
        ]

        let files = try textFiles(under: appURL, matching: textExtensions)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for pattern in secretPatterns {
                XCTAssertNil(
                    text.range(of: pattern, options: .regularExpression),
                    "\(relativePath(file)) contains a provider secret-like value"
                )
            }
        }
    }

    private func plistDictionary(at url: URL) throws -> [String: String] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: String])
    }

    private func textFiles(under root: URL, matching extensions: Set<String>) throws -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else {
                return nil
            }
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true, extensions.contains(url.pathExtension) else {
                return nil
            }
            return url
        }
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    private func relativePath(_ url: URL) -> String {
        let root = projectURL("")
        return url.path.replacingOccurrences(of: root.path + "/", with: "")
    }
}
