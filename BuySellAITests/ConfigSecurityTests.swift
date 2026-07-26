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
            supabaseURLString: "  https://abcdefghijklmnopqrst.supabase.co  ",
            anonKey: "  sb_publishable_" + String(repeating: "A", count: 30) + "  "
        )

        XCTAssertEqual(config.supabaseURL.absoluteString, "https://abcdefghijklmnopqrst.supabase.co")
        XCTAssertEqual(config.functionsBaseURL.absoluteString, "https://abcdefghijklmnopqrst.supabase.co/functions/v1")
        XCTAssertEqual(config.anonKey, "sb_publishable_" + String(repeating: "A", count: 30))
    }

    func testRuntimeConfigAcceptsOnlyPublicSupabaseFields() throws {
        let validConfig = try AppConfig.make(dictionary: [
            "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
            "SUPABASE_ANON_KEY": "anon-test-key"
        ])

        XCTAssertEqual(validConfig.supabaseURL.absoluteString, "https://abcdefghijklmnopqrst.supabase.co")

        let configsWithExtraSecretSlots: [[String: Any]] = [
            [
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "SUPABASE_ANON_KEY": "anon-test-key",
                "GEMINI_API_KEY": "server-side-only"
            ],
            [
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "SUPABASE_ANON_KEY": "anon-test-key",
                "OPENAI_API_KEY": "server-side-only"
            ],
            [
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "SUPABASE_ANON_KEY": "anon-test-key",
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
            "sk-" + String(repeating: "A", count: 30),
            "sb_secret_" + String(repeating: "A", count: 30)
        ]

        for secretLikeValue in providerSecretLikeValues {
            XCTAssertThrowsError(
                try AppConfig.make(
                    supabaseURLString: "https://abcdefghijklmnopqrst.supabase.co",
                    anonKey: secretLikeValue
                )
            ) { error in
                XCTAssertEqual(error as? APIError, .notConfigured)
            }
        }
    }

    func testRuntimeConfigRejectsProviderSecretShapedSupabaseURLs() throws {
        let providerSecretLikeURLs = [
            "https://sk-" + String(repeating: "A", count: 30) + ".supabase.co",
            "https://sb_secret_" + String(repeating: "A", count: 30) + ".supabase.co",
            "https://abcdefghijklmnopqrst.supabase.co?token=AQ." + String(repeating: "A", count: 30),
            "https://AIza" + String(repeating: "A", count: 30) + "@abcdefghijklmnopqrst.supabase.co"
        ]

        for url in providerSecretLikeURLs {
            XCTAssertThrowsError(
                try AppConfig.make(
                    supabaseURLString: url,
                    anonKey: "anon-test-key"
                )
            ) { error in
                XCTAssertEqual(error as? APIError, .notConfigured)
            }
        }
    }

    func testRuntimeConfigRejectsCopiedExamplePlaceholders() throws {
        XCTAssertThrowsError(
            try AppConfig.make(supabaseURLString: "https://project-ref.supabase.co", anonKey: "anon-test-key")
        ) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }

        XCTAssertThrowsError(
            try AppConfig.make(supabaseURLString: "https://abcdefghijklmnopqrst.supabase.co", anonKey: "public-anon-key")
        ) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
    }

    func testRuntimeConfigNormalizesTrailingSlashOnProjectRoot() throws {
        let config = try AppConfig.make(
            supabaseURLString: "https://abcdefghijklmnopqrst.supabase.co/",
            anonKey: "anon-test-key"
        )

        XCTAssertEqual(config.supabaseURL.absoluteString, "https://abcdefghijklmnopqrst.supabase.co")
        XCTAssertEqual(config.functionsBaseURL.absoluteString, "https://abcdefghijklmnopqrst.supabase.co/functions/v1")
    }

    func testRuntimeConfigRejectsInsecureOrNonSupabaseURLs() throws {
        let invalidURLs = [
            "http://abcdefghijklmnopqrst.supabase.co",
            "https://supabase.co",
            "https://nested.abcdefghijklmnopqrst.supabase.co",
            "https://example.com",
            "not a url",
            "https://abcdefghijklmnopqrst.supabase.co/functions/v1",
            "https://abcdefghijklmnopqrst.supabase.co?redirect=https://example.com",
            "https://abcdefghijklmnopqrst.supabase.co#fragment",
            "https://anon@abcdefghijklmnopqrst.supabase.co",
            "https://abcdefghijklmnopqrst.supabase.co:443"
        ]

        for url in invalidURLs {
            XCTAssertThrowsError(try AppConfig.make(supabaseURLString: url, anonKey: "anon-test-key")) { error in
                XCTAssertEqual(error as? APIError, .notConfigured)
            }
        }
    }

    func testRuntimeConfigRejectsBlankAnonKey() throws {
        XCTAssertThrowsError(
            try AppConfig.make(supabaseURLString: "https://abcdefghijklmnopqrst.supabase.co", anonKey: "   ")
        ) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
    }

    func testRuntimeConfigLoadMapsMalformedPlistReadsToNotConfigured() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/App/Config.swift"), encoding: .utf8)
        let loadRange = try XCTUnwrap(source.range(of: "static func load() throws -> AppConfig"))
        let makeRange = try XCTUnwrap(source.range(of: "static func make(dictionary:", range: loadRange.upperBound..<source.endIndex))
        let loadSource = String(source[loadRange.lowerBound..<makeRange.lowerBound])

        XCTAssertNotNil(loadSource.range(of: "do {"))
        XCTAssertNotNil(loadSource.range(of: "catch let error as APIError"))
        XCTAssertNotNil(loadSource.range(of: "throw error"))
        XCTAssertNotNil(loadSource.range(of: "catch {\n            throw APIError.notConfigured\n        }"))
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

        for expectedPath in [".env", ".env.*", "!.env.example", "supabase/.temp/", "*.xcresult/", "*.xcarchive/", "*.ipa", "*.dSYM/"] {
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
        XCTAssertNotNil(script.range(of: #"sb_secret_[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: "scan_root()"))
        XCTAssertNotNil(script.range(of: "self_test()"))
        XCTAssertNotNil(script.range(of: "mktemp -d"))
        XCTAssertNotNil(script.range(of: "M10 secret scan self-test passed"))
        XCTAssertNotNil(script.range(of: "--glob '!.git/*'"))
        XCTAssertNotNil(script.range(of: "--glob '!*.xcresult/**'"))
        XCTAssertNotNil(script.range(of: "--glob '!*.xcarchive/**'"))
        XCTAssertNotNil(script.range(of: "--glob '!*.dSYM/**'"))
        XCTAssertNotNil(script.range(of: "M10 secret scan failed"))
        XCTAssertNotNil(script.range(of: "M10 secret scan passed"))
    }

    func testSupabaseAppConfigSetupScriptWritesOnlyPublicConfigAndRejectsSecrets() throws {
        let scriptURL = projectURL("Scripts/setup_supabase_config.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "BuySellAI/App/Config.plist"))
        XCTAssertNotNil(script.range(of: "SUPABASE_URL"))
        XCTAssertNotNil(script.range(of: "SUPABASE_ANON_KEY"))
        XCTAssertNotNil(script.range(of: "SUPABASE_CONFIG_FROM_ENV"))
        XCTAssertNotNil(script.range(of: "read_required_or_env \"Supabase project URL: \" supabase_url SUPABASE_URL"))
        XCTAssertNotNil(script.range(of: "read_required_or_env \"Supabase anon key: \" anon_key SUPABASE_ANON_KEY"))
        XCTAssertNotNil(script.range(of: "is required in environment when SUPABASE_CONFIG_FROM_ENV=1"))
        XCTAssertNotNil(script.range(of: "project-ref.supabase.co"))
        XCTAssertNotNil(script.range(of: "public-anon-key"))
        XCTAssertNotNil(script.range(of: "provider/server-secret-shaped"))
        XCTAssertNotNil(script.range(of: #"AQ\.[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: #"AIza[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: #"sk-[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: #"sb_secret_[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: "SUPABASE_URL must be a root https://<project>.supabase.co URL"))
        XCTAssertNotNil(script.range(of: "write_public_config()"))
        XCTAssertNotNil(script.range(of: #"PlistBuddy -c "Clear dict""#))
        XCTAssertNotNil(script.range(of: #"PlistBuddy -c "Add :SUPABASE_URL string $public_url""#))
        XCTAssertNotNil(script.range(of: #"PlistBuddy -c "Add :SUPABASE_ANON_KEY string $public_anon_key""#))
        XCTAssertNotNil(script.range(of: "plistlib.dump(config, handle"))
        XCTAssertNotNil(script.range(of: "Supabase app config written"))
        XCTAssertNotNil(script.range(of: "keys: SUPABASE_URL SUPABASE_ANON_KEY"))
        XCTAssertNil(script.range(of: "GEMINI_API_KEY"))
        XCTAssertNil(script.range(of: "SUPABASE_SERVICE_ROLE_KEY"))
        XCTAssertNil(script.range(of: "APPLE_PRIVATE_KEY"))
    }

    func testM10DocsUseRepeatableSecretScanScript() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/scan_m10_secrets.sh"))
        XCTAssertNotNil(readme.range(of: "M10 secret scan self-test passed"))
        XCTAssertNotNil(readme.range(of: "Rotate any provider or server-side key that was pasted into chat, logs, or git"))
        XCTAssertNotNil(readme.range(of: "Scripts/setup_supabase_config.sh"))
        XCTAssertNotNil(readme.range(of: "rejects copied placeholders and provider/server-secret-shaped values"))
        XCTAssertNotNil(readme.range(of: "Scripts/setup_supabase_secrets.sh full"))
        XCTAssertNotNil(readme.range(of: "0600 temporary env file outside the repository"))
        XCTAssertNotNil(readme.range(of: "Do not paste provider or server-side secrets into `Config.plist`, Xcode build settings, source files, test fixtures, or shell commands"))
        XCTAssertNotNil(m10.range(of: "Scripts/scan_m10_secrets.sh"))
        XCTAssertNotNil(m10.range(of: "M10 secret scan self-test passed"))
        XCTAssertNotNil(m10.range(of: "The scan should print both `M10 secret scan self-test passed` and `M10 secret scan passed`."))
    }

    func testBundledAppTextFilesDoNotContainProviderOrServerSecrets() throws {
        let appURL = projectURL("BuySellAI")
        let textExtensions: Set<String> = ["json", "plist", "storyboard", "strings", "swift"]
        let secretPatterns = [
            #"AIza[0-9A-Za-z_-]{20,}"#,
            #"AQ\.[0-9A-Za-z_-]{20,}"#,
            #"sk-[0-9A-Za-z_-]{20,}"#,
            #"sb_secret_[0-9A-Za-z_-]{20,}"#
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
