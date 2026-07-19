import Foundation
import XCTest
@testable import BuySellAI

final class LocalizationCoverageTests: XCTestCase {
    func testLocalizedSourceKeysHaveEnglishEntries() throws {
        let localizedKeys = try loadLocalizedKeys()
        let referencedKeys = try appSwiftFiles().reduce(into: Set<String>()) { keys, file in
            let source = try String(contentsOf: file, encoding: .utf8)
            keys.formUnion(try sourceLocalizationKeys(in: source))
        }

        let missingKeys = referencedKeys.subtracting(localizedKeys)

        XCTAssertTrue(
            missingKeys.isEmpty,
            "Missing Localizable.strings entries: \(missingKeys.sorted().joined(separator: ", "))"
        )
    }

    func testModelDisplayCopyHasEnglishEntries() throws {
        let localizedKeys = try loadLocalizedKeys()
        let modelKeys = Set(
            Category.allCases.map(\.display) +
                Condition.allCases.map(\.display) +
                ThemePreference.allCases.map(\.display)
        )

        let missingKeys = modelKeys.subtracting(localizedKeys)

        XCTAssertTrue(
            missingKeys.isEmpty,
            "Missing Localizable.strings entries for model display copy: \(missingKeys.sorted().joined(separator: ", "))"
        )
    }

    func testCategoryAndConditionDisplayValuesRouteThroughLocalizationWithoutChangingAPIKeys() throws {
        let models = try String(contentsOf: projectURL("BuySellAI/Data/Models.swift"), encoding: .utf8)
        let apiClient = try String(contentsOf: projectURL("BuySellAI/Data/APIClient.swift"), encoding: .utf8)

        XCTAssertNotNil(models.range(of: "displayKey.localized"))
        XCTAssertNotNil(models.range(of: "var apiValue: String"))
        XCTAssertNotNil(apiClient.range(of: "category: item.category.apiValue"))
        XCTAssertNotNil(apiClient.range(of: "condition: item.condition.apiValue"))
        XCTAssertNil(apiClient.range(of: "category: item.category.display"))
    }

    func testThemePreferenceDisplayRoutesThroughLocalization() throws {
        let models = try String(contentsOf: projectURL("BuySellAI/Data/Models.swift"), encoding: .utf8)
        let themePreferenceSource = try XCTUnwrap(models.range(of: "enum ThemePreference").map { models[$0.lowerBound...] })

        XCTAssertNotNil(themePreferenceSource.range(of: "displayKey.localized"))
        XCTAssertNotNil(themePreferenceSource.range(of: "private var displayKey: String"))
    }

    func testSwiftUIStringLiteralsUseLocalizationWrappers() throws {
        let checkedCallPattern = #"\b(?:Text|Button|Label|Section|TextField|navigationTitle|confirmationDialog)\(\s*"((?:\\.|[^"\\])*)""#
        let regex = try NSRegularExpression(pattern: checkedCallPattern)
        let allowedRawLiterals: Set<String> = ["~$"]
        var violations: [String] = []

        for file in try appSwiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)

            for match in regex.matches(in: source, range: range) {
                guard
                    let literalRange = Range(match.range(at: 1), in: source),
                    let matchRange = Range(match.range, in: source)
                else { continue }

                let literal = source[literalRange].unescapedSwiftStringLiteral
                guard allowedRawLiterals.contains(literal) == false else { continue }

                if source[matchRange.upperBound...].hasPrefix(".localized") == false {
                    violations.append("\(relativePath(file)): \(literal)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "SwiftUI string literals should use .localized: \(violations.joined(separator: ", "))"
        )
    }

    private func sourceLocalizationKeys(in source: String) throws -> Set<String> {
        let patterns = [
            #""((?:\\.|[^"\\])*)"\.localized"#,
            #"String\.localizedFormat\("((?:\\.|[^"\\])*)""#,
            #"\b(?:PrimaryPillButton|SecondaryPillButton|GhostButton|TextActionButton)\(\s*title:\s*"((?:\\.|[^"\\])*)""#,
            #"\b(?:PrimaryPillButton|SecondaryPillButton|GhostButton|TextActionButton)\(\s*title:\s*[^,\n]*\?\s*"((?:\\.|[^"\\])*)"\s*:\s*"((?:\\.|[^"\\])*)""#,
            #"\bIconCircleButton\([\s\S]*?accessibilityLabel:\s*"((?:\\.|[^"\\])*)""#,
            #"accessibilityHint:\s*"((?:\\.|[^"\\])*)""#
        ]

        return try patterns.reduce(into: Set<String>()) { keys, pattern in
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in regex.matches(in: source, range: range) {
                for index in 1..<match.numberOfRanges {
                    let captureRange = match.range(at: index)
                    guard let swiftRange = Range(captureRange, in: source) else { continue }
                    keys.insert(source[swiftRange].unescapedSwiftStringLiteral)
                }
            }
        }
    }

    private func loadLocalizedKeys() throws -> Set<String> {
        let data = try Data(contentsOf: projectURL("BuySellAI/Resources/Localizable.strings"))
        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let strings = try XCTUnwrap(propertyList as? [String: String])
        return Set(strings.keys)
    }

    private func appSwiftFiles() throws -> [URL] {
        try files(under: projectURL("BuySellAI"), matchingExtensions: ["swift"])
    }

    private func files(under root: URL, matchingExtensions extensions: Set<String>) throws -> [URL] {
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

    private func relativePath(_ file: URL) -> String {
        let root = projectURL("")
        return file.path.replacingOccurrences(of: root.path + "/", with: "")
    }
}

private extension Substring {
    var unescapedSwiftStringLiteral: String {
        String(self)
            .replacingOccurrences(of: #"\""#, with: #"""#)
            .replacingOccurrences(of: #"\n"#, with: "\n")
            .replacingOccurrences(of: #"\t"#, with: "\t")
            .replacingOccurrences(of: #"\\"#, with: #"\"#)
    }
}
