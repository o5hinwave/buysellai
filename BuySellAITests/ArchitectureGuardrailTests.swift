import Foundation
import XCTest

final class ArchitectureGuardrailTests: XCTestCase {
    func testAppSourcesAvoidBannedArchitecturePatterns() throws {
        let patterns = [
            #"\bNavigationView\b"#,
            #"\bObservableObject\b"#,
            #"@Published\b"#,
            #"\bimport\s+Combine\b"#,
            #"\bimport\s+RxSwift\b"#,
            #"\.onAppear\s*\{"#,
            #"\bprint\s*\("#,
            #"\bTabView\b"#,
            #"\.tabItem\b"#
        ]

        try assertNoMatches(patterns, in: appSwiftFiles())
    }

    func testAppSourcesAvoidForbiddenFrameworksAndWebWrappers() throws {
        let patterns = [
            #"\bWKWebView\b"#,
            #"\bWebView\b"#,
            #"\bReactNative\b"#,
            #"\bReact\s+Native\b"#,
            #"\bFlutter\b"#,
            #"\bCapacitor\b"#,
            #"\bIonic\b"#,
            #"\bSnapKit\b"#,
            #"\bAlamofire\b"#,
            #"\bKingfisher\b"#,
            #"\bSwiftUIX\b"#,
            #"\bMoya\b"#,
            #"\bNuke\b"#,
            #"\bFirebase\b"#,
            #"\bAmplify\b"#,
            #"\bRealm\b"#,
            #"\bReactorKit\b"#
        ]

        try assertNoMatches(patterns, in: appSwiftFiles() + [projectURL("BuySellAI.xcodeproj/project.pbxproj")])
    }

    func testNoThirdPartyPackageManifestsOrXcodePackageReferences() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectURL("Package.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectURL("Package.resolved").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectURL("BuySellAI.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").path))

        let project = try String(contentsOf: projectURL("BuySellAI.xcodeproj/project.pbxproj"), encoding: .utf8)
        XCTAssertNil(project.range(of: "XCRemoteSwiftPackageReference"))
        XCTAssertNil(project.range(of: "XCSwiftPackageProductDependency"))
    }

    func testRemovedProductConceptsStayOutOfAppCopy() throws {
        let patterns = [
            #"\bInventory\b"#,
            #"\bProfit\b"#,
            #"\bTax\b"#,
            #"\bSold\b"#,
            #"\bPro\s+plan\b"#,
            #"\bsubscription\b"#,
            #"\bupsell\b"#,
            #"\breferral\b"#,
            #"\bcoach\s+mark\b"#,
            #"\bspotlight\b"#,
            #"\btooltip\b"#,
            #"\bAI-generated\b"#,
            #"\bwatermark\b"#,
            #"\bdashboard\b"#
        ]

        try assertNoMatches(patterns, in: appTextFiles())
    }

    func testAppCopyAvoidsForbiddenToneWords() throws {
        let patterns = [
            #"\b[Jj]ust\b"#,
            #"\b[Ss]imply\b"#
        ]

        try assertNoMatches(patterns, in: appTextFiles())
        try assertNoSellerReferencesExceptAllowedMarketplaceBlurbs()
    }

    func testTutorialKeepsKeyboardNavigationSupport() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"\.focusable\(\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"\.onKeyPress\(\.space\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"\.onKeyPress\(\.rightArrow\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"\.onKeyPress\(\.leftArrow\)"#, options: .regularExpression))
    }

    func testAppSourcesDoNotForceUnwrap() throws {
        try assertNoMatches([#"[A-Za-z0-9_\)\]]!"#], in: appSwiftFiles())
    }

    func testSwiftUIColorUsageRoutesPureBlackAndWhiteThroughTokens() throws {
        let patterns = [
            #"\bColor\.black\b"#,
            #"\bColor\.white\b"#,
            #"\bColor\s*=\s*\.black\b"#,
            #"\bColor\s*=\s*\.white\b"#
        ]

        try assertNoMatches(patterns, in: appSwiftFiles())
    }

    func testLoggerCallsDoNotReferenceSensitivePayloadsOrUserIdentifiers() throws {
        let sensitiveTerms = [
            "Authorization",
            "accessToken",
            "base64",
            "email",
            "httpBody",
            "idToken",
            "imageDataUrl",
            "password",
            "refreshToken"
        ]

        for sourceFile in try appSwiftFiles() {
            let lines = try String(contentsOf: sourceFile, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let text = String(line)
                guard text.contains("Logger") || text.contains("logger.") || text.contains("os_log") else {
                    continue
                }

                for term in sensitiveTerms {
                    XCTAssertFalse(
                        text.localizedCaseInsensitiveContains(term),
                        "\(relativePath(sourceFile)):\(index + 1) logs sensitive term \(term)"
                    )
                }
            }
        }
    }

    private func assertNoMatches(
        _ patterns: [String],
        in files: [URL],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for sourceFile in files {
            let text = try String(contentsOf: sourceFile, encoding: .utf8)
            for pattern in patterns {
                XCTAssertNil(
                    text.range(of: pattern, options: .regularExpression),
                    "\(relativePath(sourceFile)) matches banned pattern \(pattern)",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func assertNoSellerReferencesExceptAllowedMarketplaceBlurbs(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let allowedPhrases = [
            "Fashion, no seller fees",
            "Amazon seller — high reach, high fee"
        ]
        for sourceFile in try appTextFiles() {
            let sourceText = try String(contentsOf: sourceFile, encoding: .utf8)
            let text = allowedPhrases.reduce(sourceText) { partial, phrase in
                partial.replacingOccurrences(of: phrase, with: "")
            }
            XCTAssertNil(
                text.range(of: #"\b[Ss]eller\b"#, options: .regularExpression),
                "\(relativePath(sourceFile)) contains a user-facing seller reference outside the allowed marketplace blurbs",
                file: file,
                line: line
            )
        }
    }

    private func appSwiftFiles() throws -> [URL] {
        try files(under: projectURL("BuySellAI"), matchingExtensions: ["swift"])
    }

    private func appTextFiles() throws -> [URL] {
        try files(under: projectURL("BuySellAI"), matchingExtensions: ["swift", "strings"])
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

    private func relativePath(_ url: URL) -> String {
        let root = projectURL("")
        return url.path.replacingOccurrences(of: root.path + "/", with: "")
    }
}
