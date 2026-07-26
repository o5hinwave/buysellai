import Foundation
import XCTest

final class WorkspaceMaterializationScriptTests: XCTestCase {
    func testWorkspaceMaterializationScriptRehydratesDatalessFilesBeforeFailing() throws {
        let script = try String(contentsOf: projectURL("Scripts/check_workspace_materialization.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "ALLOW_DATALLESS_WORKSPACE"))
        XCTAssertNotNil(script.range(of: "materialize_if_dataless"))
        XCTAssertNotNil(script.range(of: #"cat "$path" >/dev/null 2>&1"#))
        XCTAssertNotNil(script.range(of: #"materialize_if_dataless "$path""#))
        XCTAssertNotNil(script.range(of: "M10 workspace materialization passed"))
    }

    func testAcceptanceDocsRouteWorkspaceMaterializationThroughVerifier() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(readme.range(of: "Scripts/check_workspace_materialization.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/check_workspace_materialization.sh"))
        XCTAssertNotNil(m10.range(of: "M10 workspace materialization passed"))
        XCTAssertNotNil(m10.range(of: "ALLOW_DATALLESS_WORKSPACE=1"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
