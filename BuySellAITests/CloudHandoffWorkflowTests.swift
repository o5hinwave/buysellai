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
            "Scripts/scan_m10_secrets.sh",
            "M10_EXPECT_SUPPORT_SITE=0 Scripts/check_workspace_materialization.sh",
            "git diff --check",
            "Scripts/check_supabase_schema.sh",
            "Scripts/check_supabase_functions.sh",
            "Scripts/ci_boot_simulator.sh",
            "IOS_TEST_DESTINATION",
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
            XCTAssertNotNil(text.range(of: ".github/workflows/app-store-preflight.yml"))
            XCTAssertNotNil(text.range(of: "App Store Preflight"))
            XCTAssertNotNil(text.range(of: ".github/workflows/supabase-backend-deploy.yml"))
            XCTAssertNotNil(text.range(of: "Supabase Backend Deploy"))
            XCTAssertNotNil(text.range(of: "Scripts/check_supabase_schema.sh"))
            XCTAssertNotNil(text.range(of: "Scripts/check_supabase_functions.sh"))
            XCTAssertNotNil(text.range(of: "AppStoreSite"))
            XCTAssertNotNil(text.range(of: "Sites"))
        }
    }

    func testAppStorePreflightWorkflowRunsReleaseLaneFromCloud() throws {
        let workflowURL = projectURL(".github/workflows/app-store-preflight.yml")
        let workflow = try String(contentsOf: workflowURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: workflowURL.path))
        [
            "name: App Store Preflight",
            "workflow_dispatch:",
            "allow_missing_credentials",
            "runs-on: macos-15",
            "actions/checkout@v4",
            "Scripts/scan_m10_secrets.sh",
            "M10_EXPECT_SUPPORT_SITE=0 Scripts/check_workspace_materialization.sh",
            "Scripts/check_supabase_schema.sh",
            "Scripts/check_supabase_functions.sh",
            "M10_DEVELOPMENT_TEAM: ${{ secrets.M10_DEVELOPMENT_TEAM }}",
            "ASC_API_KEY_ID: ${{ secrets.ASC_API_KEY_ID }}",
            "ASC_API_ISSUER_ID: ${{ secrets.ASC_API_ISSUER_ID }}",
            "ASC_API_PRIVATE_KEY: ${{ secrets.ASC_API_PRIVATE_KEY }}",
            "IOS_DISTRIBUTION_CERTIFICATE_BASE64",
            "IOS_PROVISIONING_PROFILE_BASE64",
            "Scripts/verify_app_store_cloud_credentials.sh",
            "/tmp/buysell-app-store-cloud-credentials.log",
            "Scripts/preflight_m10_signed_archive.sh",
            "Scripts/preflight_m10_app_store_export.sh",
            "Scripts/preflight_m10_app_store_validate.sh",
            "actions/upload-artifact@v4",
        ].forEach { expected in
            XCTAssertNotNil(workflow.range(of: expected), "Missing expected App Store workflow step: \(expected)")
        }
    }

    func testSupabaseBackendDeployWorkflowRunsGuardedCloudDeploy() throws {
        let workflowURL = projectURL(".github/workflows/supabase-backend-deploy.yml")
        let workflow = try String(contentsOf: workflowURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: workflowURL.path))
        [
            "name: Supabase Backend Deploy",
            "workflow_dispatch:",
            "mode:",
            "preflight",
            "functions",
            "deploy",
            "confirm_project_ref",
            "runs-on: ubuntu-latest",
            "permissions:",
            "contents: read",
            "actions/checkout@v4",
            "supabase/setup-cli@v1",
            "SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}",
            "SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}",
            "SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}",
            "SUPABASE_URL: ${{ secrets.SUPABASE_URL }}",
            "SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}",
            "SUPABASE_CONFIG_FROM_ENV: \"1\"",
            "M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS",
            "for name in SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF SUPABASE_URL SUPABASE_ANON_KEY; do",
            "SUPABASE_DB_PASSWORD GitHub secret is required for deploy mode on GitHub hosted runners so Supabase CLI can link through the IPv4 pooler instead of the direct IPv6 database host",
            "confirm_project_ref must match SUPABASE_PROJECT_REF for deploy mode",
            "Scripts/scan_m10_secrets.sh",
            "Scripts/setup_supabase_config.sh",
            "Record Supabase project",
            "printf '%s' \"$SUPABASE_PROJECT_REF\" > supabase/.temp/project-ref",
            "Link Supabase project for deploy",
            "if: ${{ inputs.mode == 'deploy' }}",
            "supabase link --project-ref \"$SUPABASE_PROJECT_REF\" --password \"$SUPABASE_DB_PASSWORD\" --yes",
            "Scripts/check_supabase_schema.sh",
            "Scripts/check_supabase_functions.sh",
            "CONFIRM_SUPABASE_DEPLOY=\"$SUPABASE_PROJECT_REF\"",
            "Scripts/deploy_supabase_backend.sh deploy",
            "Scripts/deploy_supabase_backend.sh functions",
            "Scripts/deploy_supabase_backend.sh preflight",
            "actions/upload-artifact@v4",
            "SupabaseBackendDeployLog",
        ].forEach { expected in
            XCTAssertNotNil(workflow.range(of: expected), "Missing expected Supabase deploy workflow step: \(expected)")
        }
    }

    func testCloudWorkflowsCreateAnAvailableSimulatorInsteadOfPinningRuntime() throws {
        let ci = try String(contentsOf: projectURL(".github/workflows/ios-ci.yml"), encoding: .utf8)
        let handoff = try String(contentsOf: projectURL(".github/workflows/cloud-handoff.yml"), encoding: .utf8)
        let helper = try String(contentsOf: projectURL("Scripts/ci_boot_simulator.sh"), encoding: .utf8)

        for workflow in [ci, handoff] {
            XCTAssertNotNil(workflow.range(of: "Scripts/ci_boot_simulator.sh"))
            XCTAssertNotNil(workflow.range(of: "IOS_TEST_DESTINATION"))
            XCTAssertNotNil(workflow.range(of: #"destination="$(Scripts/ci_boot_simulator.sh)""#))
            XCTAssertNotNil(workflow.range(of: #"printf 'IOS_TEST_DESTINATION=%s\n' "$destination""#))
            XCTAssertNotNil(workflow.range(of: #"-destination "$IOS_TEST_DESTINATION""#))
            XCTAssertNil(workflow.range(of: "OS=18.5"))
        }

        XCTAssertNotNil(helper.range(of: #""xcrun", "simctl", "list", "runtimes", "--json""#))
        XCTAssertNotNil(helper.range(of: #""xcrun", "simctl", "list", "devices", "--json""#))
        XCTAssertNotNil(helper.range(of: "timeout=90"))
        XCTAssertNotNil(helper.range(of: "timeout=30"))
        XCTAssertNotNil(helper.range(of: "timeout=60"))
        XCTAssertNotNil(helper.range(of: "timeout=120"))
        XCTAssertNotNil(helper.range(of: "iPhone 16 Pro"))
        XCTAssertNotNil(helper.range(of: "if existing_udid:"))
        XCTAssertNotNil(helper.range(of: #""xcrun", "simctl", "create""#))
        XCTAssertNotNil(helper.range(of: #""xcrun", "simctl", "bootstatus""#))
        XCTAssertNotNil(helper.range(of: "id=%s"))
    }

    func testWorkspaceMaterializationDoesNotRequireALocalMainBranchInCloudCheckouts() throws {
        let script = try String(contentsOf: projectURL("Scripts/check_workspace_materialization.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "check_git_head_resolves"))
        XCTAssertNotNil(script.range(of: "M10_EXPECT_SUPPORT_SITE"))
        XCTAssertNotNil(script.range(of: "M10_GIT_CHECK_TIMEOUT"))
        XCTAssertNotNil(script.range(of: "git_with_timeout"))
        XCTAssertNotNil(script.range(of: "git_with_timeout rev-parse --verify HEAD"))
        XCTAssertNotNil(script.range(of: "git_with_timeout status --short"))
        XCTAssertNotNil(script.range(of: #"if [[ -f ".git/refs/heads/main" ]]; then"#))
        XCTAssertNotNil(script.range(of: "support-site: external Sites project"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
