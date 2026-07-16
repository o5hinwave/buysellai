import Foundation
import XCTest
@testable import BuySellAI

final class ConfigSecurityTests: XCTestCase {
    func testConfigExampleOnlyContainsPublicSupabaseFields() throws {
        let plist = try plistDictionary(at: projectURL("BuySellAI/App/Config.plist.example"))

        XCTAssertEqual(Set(plist.keys), ["SUPABASE_URL", "SUPABASE_ANON_KEY"])
    }

    func testRuntimeConfigAcceptsHTTPSProjectSupabaseURLAndTrimsValues() throws {
        let config = try AppConfig.make(
            supabaseURLString: "  https://project-ref.supabase.co  ",
            anonKey: "  public-anon-key  "
        )

        XCTAssertEqual(config.supabaseURL.absoluteString, "https://project-ref.supabase.co")
        XCTAssertEqual(config.functionsBaseURL.absoluteString, "https://project-ref.supabase.co/functions/v1")
        XCTAssertEqual(config.anonKey, "public-anon-key")
    }

    func testRuntimeConfigAcceptsOnlyPublicSupabaseFields() throws {
        let validConfig = try AppConfig.make(dictionary: [
            "SUPABASE_URL": "https://project-ref.supabase.co",
            "SUPABASE_ANON_KEY": "public-anon-key"
        ])

        XCTAssertEqual(validConfig.supabaseURL.absoluteString, "https://project-ref.supabase.co")

        let configsWithExtraSecretSlots: [[String: Any]] = [
            [
                "SUPABASE_URL": "https://project-ref.supabase.co",
                "SUPABASE_ANON_KEY": "public-anon-key",
                "GEMINI_API_KEY": "server-side-only"
            ],
            [
                "SUPABASE_URL": "https://project-ref.supabase.co",
                "SUPABASE_ANON_KEY": "public-anon-key",
                "OPENAI_API_KEY": "server-side-only"
            ],
            [
                "SUPABASE_URL": "https://project-ref.supabase.co",
                "SUPABASE_ANON_KEY": "public-anon-key",
                "ANTHROPIC_API_KEY": "server-side-only"
            ]
        ]

        for config in configsWithExtraSecretSlots {
            XCTAssertThrowsError(try AppConfig.make(dictionary: config)) { error in
                XCTAssertEqual(error as? APIError, .notConfigured)
            }
        }
    }

    func testRuntimeConfigRejectsProviderSecretShapedAnonKeys() throws {
        let providerSecretLikeValues = [
            "AQ." + String(repeating: "A", count: 30),
            "AIza" + String(repeating: "A", count: 30),
            "sk-" + String(repeating: "A", count: 30)
        ]

        for secretLikeValue in providerSecretLikeValues {
            XCTAssertThrowsError(
                try AppConfig.make(
                    supabaseURLString: "https://project-ref.supabase.co",
                    anonKey: secretLikeValue
                )
            ) { error in
                XCTAssertEqual(error as? APIError, .notConfigured)
            }
        }
    }

    func testRuntimeConfigNormalizesTrailingSlashOnProjectRoot() throws {
        let config = try AppConfig.make(
            supabaseURLString: "https://project-ref.supabase.co/",
            anonKey: "public-anon-key"
        )

        XCTAssertEqual(config.supabaseURL.absoluteString, "https://project-ref.supabase.co")
        XCTAssertEqual(config.functionsBaseURL.absoluteString, "https://project-ref.supabase.co/functions/v1")
    }

    func testRuntimeConfigRejectsInsecureOrNonSupabaseURLs() throws {
        let invalidURLs = [
            "http://project-ref.supabase.co",
            "https://supabase.co",
            "https://nested.project-ref.supabase.co",
            "https://example.com",
            "not a url",
            "https://project-ref.supabase.co/functions/v1",
            "https://project-ref.supabase.co?redirect=https://example.com",
            "https://project-ref.supabase.co#fragment",
            "https://anon@project-ref.supabase.co",
            "https://project-ref.supabase.co:443"
        ]

        for url in invalidURLs {
            XCTAssertThrowsError(try AppConfig.make(supabaseURLString: url, anonKey: "public-anon-key")) { error in
                XCTAssertEqual(error as? APIError, .notConfigured)
            }
        }
    }

    func testRuntimeConfigRejectsBlankAnonKey() throws {
        XCTAssertThrowsError(
            try AppConfig.make(supabaseURLString: "https://project-ref.supabase.co", anonKey: "   ")
        ) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
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

    func testLocalSecretFilesAndGeneratedXcodeArtifactsAreGitIgnored() throws {
        let gitignore = try String(contentsOf: projectURL(".gitignore"), encoding: .utf8)
        let ignoredPaths = Set(
            gitignore
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.isEmpty == false && $0.hasPrefix("#") == false }
        )

        for expectedPath in [".env", ".env.*", "!.env.example", "*.xcresult/", "*.xcarchive/", "*.ipa", "*.dSYM/"] {
            XCTAssertTrue(ignoredPaths.contains(expectedPath), "\(expectedPath) should stay ignored for local QA hygiene")
        }
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

    func testM10SecretScanScriptSearchesHiddenFilesAndSkipsGeneratedBundles() throws {
        let script = try String(contentsOf: projectURL("Scripts/scan_m10_secrets.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "rg -l -I --hidden"))
        XCTAssertNotNil(script.range(of: #"AQ\.[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: #"AIza[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: #"sk-[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: "--glob '!.git/*'"))
        XCTAssertNotNil(script.range(of: "--glob '!*.xcresult/**'"))
        XCTAssertNotNil(script.range(of: "--glob '!*.xcarchive/**'"))
        XCTAssertNotNil(script.range(of: "--glob '!*.dSYM/**'"))
        XCTAssertNotNil(script.range(of: "M10 secret scan failed"))
        XCTAssertNotNil(script.range(of: "M10 secret scan passed"))
    }

    func testM10DocsUseRepeatableSecretScanScript() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/scan_m10_secrets.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/scan_m10_secrets.sh"))
        XCTAssertNotNil(m10.range(of: "The scan should print `M10 secret scan passed`."))
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
