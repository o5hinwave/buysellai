import Foundation
import XCTest

final class BackendFunctionSourceTests: XCTestCase {
    func testSupabaseFunctionSourcesExistForAllAppRoutes() throws {
        for path in [
            "supabase/config.toml",
            "supabase/functions/analyze-image/index.ts",
            "supabase/functions/generate-listing/index.ts",
            "supabase/functions/delete-account/index.ts",
            "supabase/functions/_shared/gemini.ts",
            "supabase/functions/_shared/http.ts"
        ] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL(path).path), "\(path) should exist")
        }
    }

    func testAnonymousAnalyzeAndGenerateFunctionsUseGeminiServerSideSecret() throws {
        let config = try read("supabase/config.toml")
        XCTAssertNotNil(config.range(of: #"\[functions\.analyze-image\]\s+verify_jwt = false"#, options: .regularExpression))
        XCTAssertNotNil(config.range(of: #"\[functions\.generate-listing\]\s+verify_jwt = false"#, options: .regularExpression))
        XCTAssertNotNil(config.range(of: #"\[functions\.delete-account\]\s+verify_jwt = true"#, options: .regularExpression))

        let gemini = try read("supabase/functions/_shared/gemini.ts")
        XCTAssertNotNil(gemini.range(of: #"requireEnv("GEMINI_API_KEY")"#))
        XCTAssertNotNil(gemini.range(of: "generativelanguage.googleapis.com/v1beta/models/"))
        XCTAssertNotNil(gemini.range(of: ":generateContent?key="))
        XCTAssertNotNil(gemini.range(of: "gemini-3.5-flash"))
        XCTAssertNotNil(gemini.range(of: "GEMINI_MODEL"))
        XCTAssertNotNil(gemini.range(of: "generationConfig"))
        XCTAssertNil(gemini.range(of: "generation_config"))
        XCTAssertNotNil(gemini.range(of: "response_mime_type"))
        XCTAssertNotNil(gemini.range(of: "application/json"))
        XCTAssertNil(gemini.range(of: #"AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}"#, options: .regularExpression))
    }

    func testAnalyzeFunctionPreservesNativeAnalyzeContract() throws {
        let source = try read("supabase/functions/analyze-image/index.ts")

        XCTAssertNotNil(source.range(of: "imageDataUrl"))
        XCTAssertNotNil(source.range(of: "data:image/jpeg;base64,"))
        XCTAssertNotNil(source.range(of: #"inline_data: \{ mime_type: "image/jpeg""#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: "name"))
        XCTAssertNotNil(source.range(of: "category"))
        XCTAssertNotNil(source.range(of: "condition"))
        XCTAssertNotNil(source.range(of: "currentPrice"))
        XCTAssertNotNil(source.range(of: "follow-up-question"))
        XCTAssertNotNil(source.range(of: "deductible"))
        XCTAssertNotNil(source.range(of: "tax"))
    }

    func testGenerateListingFunctionPreservesNativeListingContract() throws {
        let source = try read("supabase/functions/generate-listing/index.ts")

        XCTAssertNotNil(source.range(of: "item"))
        XCTAssertNotNil(source.range(of: "platform"))
        XCTAssertNotNil(source.range(of: "originalPrice"))
        XCTAssertNotNil(source.range(of: "currentPrice"))
        XCTAssertNotNil(source.range(of: "TITLE"))
        XCTAssertNotNil(source.range(of: "DESCRIPTION"))
        XCTAssertNotNil(source.range(of: "listing"))
        XCTAssertNotNil(source.range(of: "plain text newlines"))
    }

    func testDeleteAccountFunctionRequiresServiceRoleAndDeletesHistoryAndAuthUser() throws {
        let source = try read("supabase/functions/delete-account/index.ts")

        XCTAssertNotNil(source.range(of: #"requireEnv("SUPABASE_SERVICE_ROLE_KEY")"#))
        XCTAssertNotNil(source.range(of: "requireBearerToken"))
        XCTAssertNotNil(source.range(of: "/auth/v1/user"))
        XCTAssertNotNil(source.range(of: "/rest/v1/history?user_id=eq."))
        XCTAssertNotNil(source.range(of: "/auth/v1/admin/users/"))
        XCTAssertNotNil(source.range(of: "serviceHeaders(serviceRoleKey)"))
    }

    func testBackendDocsExplainDeployAndSecretHandling() throws {
        let readme = try read("README.md")
        let backendReadme = try read("supabase/README.md")

        for text in [readme, backendReadme] {
            XCTAssertNotNil(text.range(of: "supabase functions deploy analyze-image"))
            XCTAssertNotNil(text.range(of: "supabase functions deploy generate-listing"))
            XCTAssertNotNil(text.range(of: "supabase functions deploy delete-account"))
            XCTAssertNotNil(text.range(of: "GEMINI_API_KEY"))
            XCTAssertNotNil(text.range(of: "server-side"))
        }
    }

    func testSupabaseReadmeUsesTemporaryEnvSecretWorkflow() throws {
        let backendReadme = try read("supabase/README.md")

        XCTAssertNotNil(backendReadme.range(of: #"read -rsp "Gemini API key: " GEMINI_API_KEY"#))
        XCTAssertNotNil(backendReadme.range(of: #"read -rsp "Supabase service-role key: " SUPABASE_SERVICE_ROLE_KEY"#))
        XCTAssertNotNil(backendReadme.range(of: "supabase secrets set --env-file .env"))
        XCTAssertNotNil(backendReadme.range(of: "rm .env"))
        XCTAssertNotNil(backendReadme.range(of: "unset GEMINI_API_KEY SUPABASE_SERVICE_ROLE_KEY"))
        XCTAssertNotNil(backendReadme.range(of: "Rotate any provider key that was pasted into chat, logs, or git"))
        XCTAssertNotNil(backendReadme.range(of: "The final M10 secret scan reads hidden files"))
    }

    func testBackendReadinessDocsRouteThroughSmokePreflight() throws {
        let readme = try read("README.md")
        let acceptance = try read("M10_ACCEPTANCE.md")

        for text in [readme, acceptance] {
            XCTAssertNotNil(text.range(of: "Scripts/preflight_m10_backend.sh"))
            XCTAssertNotNil(text.range(of: "M10_ANALYZE_IMAGE_JPEG"))
            XCTAssertNotNil(text.range(of: "functions: analyze-image generate-listing"))
            XCTAssertNotNil(text.range(of: "supabase/functions/"))
            XCTAssertNotNil(text.range(of: "SUPABASE_SERVICE_ROLE_KEY"))
        }
    }

    func testSupabaseFunctionSourcesContainNoProviderSecretLiterals() throws {
        let secretPattern = #"AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}"#
        for file in try textFiles(under: projectURL("supabase")) {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertNil(
                text.range(of: secretPattern, options: .regularExpression),
                "\(relativePath(file)) contains a provider secret-shaped value"
            )
        }
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: projectURL(path), encoding: .utf8)
    }

    private func textFiles(under root: URL) throws -> [URL] {
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
            guard values.isRegularFile == true, ["md", "toml", "ts"].contains(url.pathExtension) else {
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
