import Foundation
import XCTest

final class CloudHandoffWorkflowTests: XCTestCase {
    func testCloudHandoffWorkflowVerifiesPortableAppBackendAndStorefrontSources() throws {
        let workflowURL = projectURL(".github/workflows/cloud-handoff.yml")
        let workflow = try String(contentsOf: workflowURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: workflowURL.path))
        [
            "name: Cloud Handoff Check",
            "workflow_dispatch:",
            "runs-on: macos-15",
            "actions/checkout@v4",
            "actions/setup-node@v4",
            "node-version: \"22\"",
            "Scripts/scan_m10_secrets.sh",
            "Scripts/check_workspace_materialization.sh",
            "git diff --check",
            "Scripts/check_supabase_schema.sh",
            "Scripts/check_supabase_functions.sh",
            "working-directory: AppStoreSite",
            "npm ci",
            "npm test",
            "xcodebuild test",
            "WorkspaceMaterializationScriptTests",
            "CloudHandoffWorkflowTests",
            "actions/upload-artifact@v4",
        ].forEach { expected in
            XCTAssertNotNil(workflow.range(of: expected), "Missing expected workflow step: \(expected)")
        }
    }

    func testCloudSourceDocsNameTheHostedHandoffGate() throws {
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        for text in [readme, m10] {
            XCTAssertNotNil(text.range(of: ".github/workflows/cloud-handoff.yml"))
            XCTAssertNotNil(text.range(of: "Cloud Handoff Check"))
            XCTAssertNotNil(text.range(of: "Scripts/check_supabase_schema.sh"))
            XCTAssertNotNil(text.range(of: "Scripts/check_supabase_functions.sh"))
            XCTAssertNotNil(text.range(of: "AppStoreSite"))
        }
    }

    func testWorkspaceMaterializationDoesNotRequireALocalMainBranchInCloudCheckouts() throws {
        let script = try String(contentsOf: projectURL("Scripts/check_workspace_materialization.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "check_git_head_resolves"))
        XCTAssertNotNil(script.range(of: "M10_GIT_CHECK_TIMEOUT"))
        XCTAssertNotNil(script.range(of: "git_with_timeout"))
        XCTAssertNotNil(script.range(of: "git_with_timeout rev-parse --verify HEAD"))
        XCTAssertNotNil(script.range(of: "git_with_timeout status --short"))
        XCTAssertNotNil(script.range(of: #"if [[ -f ".git/refs/heads/main" ]]; then"#))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
