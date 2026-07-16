import Foundation
import XCTest

final class M10BackendPreflightScriptTests: XCTestCase {
    func testBackendPreflightScriptValidatesConfigAndCallsRequiredSupabaseRoutes() throws {
        let scriptURL = projectURL("Scripts/preflight_m10_backend.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_BACKEND"))
        XCTAssertNotNil(script.range(of: "BuySellAI/App/Config.plist"))
        XCTAssertNotNil(script.range(of: "SUPABASE_URL"))
        XCTAssertNotNil(script.range(of: "SUPABASE_ANON_KEY"))
        XCTAssertNotNil(script.range(of: "SUPABASE_URL still contains the Config.plist.example placeholder"))
        XCTAssertNotNil(script.range(of: "SUPABASE_ANON_KEY still contains the Config.plist.example placeholder"))
        XCTAssertNotNil(script.range(of: #"AQ\.[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: #"AIza[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: #"sk-[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: "M10_ANALYZE_IMAGE_JPEG"))
        XCTAssertNotNil(script.range(of: "M10_ANALYZE_IMAGE_DATA_URL"))
        XCTAssertNotNil(script.range(of: "data:image/jpeg;base64,"))
        XCTAssertNotNil(script.range(of: "curl -sS --show-error --max-time"))
        XCTAssertNotNil(script.range(of: "analyze-image"))
        XCTAssertNotNil(script.range(of: "generate-listing"))
        XCTAssertNotNil(script.range(of: "validate_analyze_response"))
        XCTAssertNotNil(script.range(of: "validate_listing_response"))
        XCTAssertNotNil(script.range(of: "currentPrice must be greater than zero"))
        XCTAssertNotNil(script.range(of: "M10 backend preflight passed"))
        XCTAssertNotNil(script.range(of: "functions: analyze-image generate-listing"))
        XCTAssertNotNil(script.range(of: "analyze item:"))
        XCTAssertNotNil(script.range(of: "listing bytes:"))
        XCTAssertNil(script.range(of: "printf 'SUPABASE_ANON_KEY"))
    }

    func testBackendPreflightPendingModeDocumentsMissingExternalState() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_backend.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10 backend preflight pending"))
        XCTAssertNotNil(script.range(of: "Config.plist is missing"))
        XCTAssertNotNil(script.range(of: "Config.plist.example placeholder"))
        XCTAssertNotNil(script.range(of: "M10_ANALYZE_IMAGE_JPEG or M10_ANALYZE_IMAGE_DATA_URL is unset"))
        XCTAssertNotNil(script.range(of: "Complete real Supabase config, deployed Edge Functions, and an analyze sample image"))
        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_BACKEND=1"))
        XCTAssertNil(script.range(of: "SUPABASE_ANON_KEY="))
    }

    func testCombinedSubmitReadinessRequiresBackendPreflightLogAndDocsRouteThroughGate() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10_BACKEND_LOG"))
        XCTAssertNotNil(script.range(of: "/tmp/buysell-submit-readiness-backend.log"))
        XCTAssertNotNil(script.range(of: "M10 backend preflight passed"))
        XCTAssertNotNil(script.range(of: "functions: analyze-image generate-listing"))
        XCTAssertNotNil(script.range(of: "backend preflight log"))
        XCTAssertNotNil(script.range(of: "M10BackendPreflightScriptTests/testBackendPreflightScriptValidatesConfigAndCallsRequiredSupabaseRoutes"))

        XCTAssertNotNil(readme.range(of: "Scripts/preflight_m10_backend.sh"))
        XCTAssertNotNil(readme.range(of: "ALLOW_MISSING_BACKEND=1"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-submit-readiness-backend.log"))
        XCTAssertNotNil(m10.range(of: "Scripts/preflight_m10_backend.sh"))
        XCTAssertNotNil(m10.range(of: "Run the M10 backend smoke preflight"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-backend.log"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
