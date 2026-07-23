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

    func testSwiftPackageReferencesAreLimitedToSupabaseSDK() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectURL("Package.swift").path))

        let project = try String(contentsOf: projectURL("BuySellAI.xcodeproj/project.pbxproj"), encoding: .utf8)
        XCTAssertEqual(project.components(separatedBy: "isa = XCRemoteSwiftPackageReference;").count - 1, 1)
        XCTAssertEqual(project.components(separatedBy: "isa = XCSwiftPackageProductDependency;").count - 1, 1)
        XCTAssertNotNil(project.range(of: #"repositoryURL = "https://github.com/supabase-community/supabase-swift";"#))
        XCTAssertNotNil(project.range(of: "minimumVersion = 2.53.0;"))
        XCTAssertNotNil(project.range(of: "productName = Supabase;"))
        XCTAssertNotNil(project.range(of: "Supabase in Frameworks"))

        let resolved = try String(contentsOf: projectURL("BuySellAI.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"), encoding: .utf8)
        XCTAssertNotNil(resolved.range(of: #""identity" : "supabase-swift""#))
        XCTAssertNotNil(resolved.range(of: #""version" : "2.53.0""#))
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
            #"\b[Ss]imply\b"#,
            #"\bWe rank every marketplace\b"#,
            #"\bAlgorithmically ranked\b"#,
            #"\bPrompt engineered\b"#,
            #"\bMarketplace arbitrage\b"#,
            #"\bKeyword density\b"#,
            #"\bConversion strategy\b"#
        ]

        try assertNoMatches(patterns, in: appTextFiles())
        try assertNoSellerReferences()
    }

    func testTutorialKeepsKeyboardNavigationSupport() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Tutorial/HowItWorksView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"\.focusable\(\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"\.onKeyPress\(\.space\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"\.onKeyPress\(\.rightArrow\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"\.onKeyPress\(\.leftArrow\)"#, options: .regularExpression))
    }

    func testAppSourcesDoNotForceUnwrap() throws {
        let patterns = [
            #"[A-Za-z0-9_\)\]]!"#,
            #"\btry\s*!"#,
            #"\bas\s*!"#,
            #"\bfatalError\s*\("#,
            #"\bpreconditionFailure\s*\("#,
            #"\bassertionFailure\s*\("#,
            #"\bprecondition\s*\("#,
            #"\bassert\s*\("#
        ]

        try assertNoMatches(patterns, in: appSwiftFiles())
    }

    func testSwiftUIColorUsageRoutesPureBlackAndWhiteThroughTokens() throws {
        let patterns = [
            #"\bColor\.black\b"#,
            #"\bColor\.white\b"#,
            #"\bColor\s*=\s*\.black\b"#,
            #"\bColor\s*=\s*\.white\b"#,
            #"\.foregroundStyle\(\s*\.(black|white)\b"#,
            #"\.foregroundColor\(\s*\.(black|white)\b"#,
            #"\.background\(\s*\.(black|white)\b"#,
            #"\.fill\(\s*\.(black|white)\b"#,
            #"\.stroke\(\s*\.(black|white)\b"#,
            #"\.tint\(\s*\.(black|white)\b"#,
            #"\.shadow\(color:\s*\.(black|white)\b"#,
            #"\bUIColor\.(black|white)\b"#
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

    func testLaunchArgumentHooksAreDebugOnlyAndCentralized() throws {
        let helperURL = projectURL("BuySellAI/App/LaunchArguments.swift")
        let helper = try String(contentsOf: helperURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: helperURL.path))
        XCTAssertNotNil(helper.range(of: "#if DEBUG"))
        XCTAssertNotNil(helper.range(of: "ProcessInfo.processInfo.arguments.contains(argument)"))
        XCTAssertNotNil(helper.range(of: "#else"))
        XCTAssertNotNil(helper.range(of: "false"))
        XCTAssertNotNil(helper.range(of: "static var isUITesting"))
        XCTAssertNotNil(helper.range(of: "--ui-testing"))
        XCTAssertNotNil(helper.range(of: "--reset-auth"))
        XCTAssertNotNil(helper.range(of: "--seed-history"))

        for sourceFile in try appSwiftFiles() where sourceFile.lastPathComponent != "LaunchArguments.swift" {
            let text = try String(contentsOf: sourceFile, encoding: .utf8)
            XCTAssertNil(
                text.range(of: "ProcessInfo.processInfo.arguments.contains"),
                "\(relativePath(sourceFile)) should route launch argument hooks through LaunchArguments"
            )
        }
    }

    func testUITestFixtureSourcesAreDebugOnly() throws {
        let imageTools = try String(contentsOf: projectURL("BuySellAI/Data/ImageTools.swift"), encoding: .utf8)
        let models = try String(contentsOf: projectURL("BuySellAI/Data/Models.swift"), encoding: .utf8)
        let apiClient = try String(contentsOf: projectURL("BuySellAI/Data/APIClient.swift"), encoding: .utf8)
        let listingStore = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingStore.swift"), encoding: .utf8)
        let appRouter = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let cameraView = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(imageTools.range(of: #"#if DEBUG\s+static func sampleJPEG\(\)"#, options: .regularExpression))
        XCTAssertNotNil(models.range(of: #"#if DEBUG\s+enum ListingFixtureText"#, options: .regularExpression))
        XCTAssertNotNil(apiClient.range(of: #"#if DEBUG\s+if isUITesting"#, options: .regularExpression))
        XCTAssertNotNil(listingStore.range(of: #"#if DEBUG\s+if LaunchArguments\.isUITesting"#, options: .regularExpression))
        XCTAssertNotNil(appRouter.range(of: #"#if DEBUG\s+let uiTestingCameraMode"#, options: .regularExpression))
        XCTAssertNotNil(appRouter.range(of: #"#if DEBUG\s+private static var uiTestingHistoryEntry"#, options: .regularExpression))
        XCTAssertNotNil(cameraView.range(of: #"#if DEBUG\s+if LaunchArguments\.contains\(LaunchArguments\.uiTestingCameraSampleCapture\)"#, options: .regularExpression))
    }

    func testLocalSourceTypecheckScriptCoversAppUnitAndUITestSources() throws {
        let scriptURL = projectURL("Scripts/typecheck_local_sources.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "xcrun --sdk iphonesimulator --show-sdk-path"))
        XCTAssertNotNil(script.range(of: "xcode-select -p"))
        XCTAssertNotNil(script.range(of: "Platforms/iPhoneSimulator.platform/Developer"))
        XCTAssertNotNil(script.range(of: "BUYSELL_TYPECHECK_MODULE_DIR"))
        XCTAssertNotNil(script.range(of: "BUYSELL_TYPECHECK_MODULE_DIR must be absolute"))
        XCTAssertNotNil(script.range(of: "BUYSELL_TYPECHECK_MODULE_DIR must be outside the repository"))
        XCTAssertNotNil(script.range(of: "BUYSELL_TYPECHECK_TARGET"))
        XCTAssertNotNil(script.range(of: "arm64-apple-ios17.0-simulator"))
        XCTAssertNotNil(script.range(of: "rg --files BuySellAI -g '*.swift'"))
        XCTAssertNotNil(script.range(of: "rg --files BuySellAITests -g '*.swift'"))
        XCTAssertNotNil(script.range(of: "rg --files BuySellAIUITests -g '*.swift'"))
        XCTAssertNotNil(script.range(of: "swift_debug=("))
        XCTAssertNotNil(script.range(of: "-D DEBUG"))
        XCTAssertNotNil(script.range(of: "-emit-module"))
        XCTAssertNotNil(script.range(of: "-module-name BuySellAIRelease"))
        XCTAssertNotNil(script.range(of: "-module-name BuySellAI"))
        XCTAssertNotNil(script.range(of: "-enable-testing"))
        XCTAssertNotNil(script.range(of: "-F \"${simulator_developer_dir}/Library/Frameworks\""))
        XCTAssertNotNil(script.range(of: "-I \"${simulator_developer_dir}/usr/lib\""))
        XCTAssertNotNil(script.range(of: "BuySellAI local source typecheck passed"))
        XCTAssertNotNil(script.range(of: "sources: app unit ui"))
        XCTAssertNotNil(script.range(of: "modes: release app debug app unit ui"))
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

    private func assertNoSellerReferences(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for sourceFile in try appTextFiles() {
            let text = try String(contentsOf: sourceFile, encoding: .utf8)
            XCTAssertNil(
                text.range(of: #"\b[Ss]eller\b"#, options: .regularExpression),
                "\(relativePath(sourceFile)) contains a user-facing seller reference",
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
