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
        XCTAssertNotNil(script.range(of: #"sb_secret_[0-9A-Za-z_-]{20,}"#))
        XCTAssertNotNil(script.range(of: "M10_ANALYZE_IMAGE_JPEG"))
        XCTAssertNotNil(script.range(of: "M10_ANALYZE_IMAGE_DATA_URL"))
        XCTAssertNotNil(script.range(of: "data:image/jpeg;base64,"))
        XCTAssertNotNil(script.range(of: "curl -sS --show-error --max-time"))
        XCTAssertNotNil(script.range(of: "analyze-image"))
        XCTAssertNotNil(script.range(of: "generate-listing"))
        XCTAssertNotNil(script.range(of: "call_rejected_function"))
        XCTAssertNotNil(script.range(of: "accepted invalid payload; expected HTTP"))
        XCTAssertNotNil(script.range(of: "invalid-analyze-missing-image-payload.json"))
        XCTAssertNotNil(script.range(of: "invalid-analyze-png-payload.json"))
        XCTAssertNotNil(script.range(of: "invalid-analyze-base64-payload.json"))
        XCTAssertNotNil(script.range(of: "invalid-analyze-jpeg-bytes-payload.json"))
        XCTAssertNotNil(script.range(of: #"imageDataUrl": "data:image/png;base64,AQID""#))
        XCTAssertNotNil(script.range(of: #"imageDataUrl": "data:image/jpeg;base64,not-base64""#))
        XCTAssertNotNil(script.range(of: #"imageDataUrl": "data:image/jpeg;base64,AQID""#))
        XCTAssertNotNil(script.range(of: "analyze-image non-JPEG bytes"))
        XCTAssertNotNil(script.range(of: "invalid-listing-platform-payload.json"))
        XCTAssertNotNil(script.range(of: "invalid-listing-category-payload.json"))
        XCTAssertNotNil(script.range(of: "invalid-listing-condition-payload.json"))
        XCTAssertNotNil(script.range(of: #"platform": "garage-sale""#))
        XCTAssertNotNil(script.range(of: #"category": "Pets""#))
        XCTAssertNotNil(script.range(of: #"condition": "broken""#))
        XCTAssertNotNil(script.range(of: "store-apple-token"))
        XCTAssertNotNil(script.range(of: "delete-account"))
        XCTAssertNotNil(script.range(of: "probe_protected_function"))
        XCTAssertNotNil(script.range(of: "probe_protected_table"))
        XCTAssertNotNil(script.range(of: "accepted an anonymous request; expected JWT protection"))
        XCTAssertNotNil(script.range(of: "protected endpoint is not deployed"))
        XCTAssertNotNil(script.range(of: "accepted an anonymous read; expected RLS/grant protection"))
        XCTAssertNotNil(script.range(of: "protected table is not deployed"))
        XCTAssertNotNil(script.range(of: "expected 401 or 403"))
        XCTAssertNotNil(script.range(of: #"rest_base="${supabase_url}/rest/v1""#))
        XCTAssertNotNil(script.range(of: "history?select=id&limit=1"))
        XCTAssertNotNil(script.range(of: "apple_auth_tokens?select=user_id&limit=1"))
        XCTAssertNotNil(script.range(of: "marketplace_research_cache?select=cache_key&limit=1"))
        XCTAssertNotNil(script.range(of: "entitlement_config?select=config_key&limit=1"))
        XCTAssertNotNil(script.range(of: "entitlement_usage_events?select=id&limit=1"))
        XCTAssertNotNil(script.range(of: "validate_analyze_response"))
        XCTAssertNotNil(script.range(of: "validate_listing_response"))
        XCTAssertNotNil(script.range(of: "currentPrice must be greater than zero"))
        XCTAssertNotNil(script.range(of: "listing contains markdown fences"))
        XCTAssertNotNil(script.range(of: "listing contains a generated preamble"))
        XCTAssertNotNil(script.range(of: "listing is missing TITLE"))
        XCTAssertNotNil(script.range(of: "listing is missing DESCRIPTION"))
        XCTAssertNotNil(script.range(of: "listing has empty TITLE"))
        XCTAssertNotNil(script.range(of: "listing has empty DESCRIPTION"))
        XCTAssertNotNil(script.range(of: "title_match = re.search"))
        XCTAssertNotNil(script.range(of: "description_match = re.search"))
        XCTAssertNotNil(script.range(of: "title_body ="))
        XCTAssertNotNil(script.range(of: "description_body ="))
        XCTAssertNotNil(script.range(of: "M10 backend preflight passed"))
        XCTAssertNotNil(script.range(of: "schema: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events"))
        XCTAssertNotNil(script.range(of: "functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account"))
        XCTAssertNotNil(script.range(of: "protected functions: store-apple-token delete-account"))
        XCTAssertNotNil(script.range(of: "protected tables: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events"))
        XCTAssertNotNil(script.range(of: "analyze item:"))
        XCTAssertNotNil(script.range(of: "analyze rejection contract: missing jpeg base64"))
        XCTAssertNotNil(script.range(of: "listing contract: title-description-plain-text"))
        XCTAssertNotNil(script.range(of: "listing rejection contract: platform category condition"))
        XCTAssertNotNil(script.range(of: "listing bytes:"))
        XCTAssertNil(script.range(of: "printf 'SUPABASE_ANON_KEY"))
    }

    func testBackendPreflightPendingModeDocumentsMissingExternalState() throws {
        let script = try String(contentsOf: projectURL("Scripts/preflight_m10_backend.sh"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10 backend preflight pending"))
        XCTAssertNotNil(script.range(of: "Config.plist is missing"))
        XCTAssertNotNil(script.range(of: "Config.plist.example placeholder"))
        XCTAssertNotNil(script.range(of: "M10_ANALYZE_IMAGE_JPEG or M10_ANALYZE_IMAGE_DATA_URL is unset"))
        XCTAssertNotNil(script.range(of: "Complete real Supabase config, deployed schema migration, deployed Edge Functions including protected account functions, and an analyze sample image"))
        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_BACKEND=1"))
        XCTAssertNotNil(script.range(of: "external_or_fail"))
        XCTAssertNotNil(script.range(of: "print_pending_and_exit"))
        XCTAssertNil(script.range(of: "SUPABASE_ANON_KEY="))
    }

    func testSupabaseFunctionDenoCheckScriptCoversEveryEdgeFunction() throws {
        let scriptURL = projectURL("Scripts/check_supabase_functions.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        [
            "DENO_BIN",
            "command -v deno",
            "npx --yes deno",
            "DENO_DIR",
            "deno-cache",
            "deno or npx is required",
            "deno_cmd",
            "check",
            "require_source_contains",
            "supabase/functions/analyze-image/index.ts",
            "supabase/functions/generate-listing/index.ts",
            "supabase/functions/store-apple-token/index.ts",
            "supabase/functions/delete-account/index.ts",
            "supabase/functions/_shared/gemini.ts",
            "supabase/functions/_shared/entitlements.ts",
            "consumeEarlyAccessUsage",
            "entitlement_config",
            "entitlement_usage_events",
            "x-buysell-device-id",
            "attachGroundingMetadata",
            "geminiGroundingSearchQueriesKey",
            "geminiGroundingSourcesKey",
            "const tools: GeminiTool[] = input.usesCachedResearch ? [] : [",
            "{ url_context: {} }",
            "{ google_search: {} }",
            "result[geminiGroundingSearchQueriesKey]",
            "result[geminiGroundingSourcesKey]",
            "requireStructuredListingDraft",
            "formatListingDraft",
            "return jsonResponse({ listing, draft, entitlement })",
            "Supabase function Deno check passed",
            "functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account",
            "listing research tools: google_search url_context gated-by-cache",
            "listing research cache: Gemini grounding saved",
            "listing draft: structured fields formatted deterministically",
            "listing evidence sources: sold-comp guarded structured source/date/status/comparability",
            "early access: server-controlled entitlements with usage protection",
            "cleanEvidenceSources(result.evidenceSources, platform)",
            "hasSoldCompEvidence",
            "listingStatusFromPriceFields",
            "For every factual market result you rely on, add one evidenceSources object",
        ].forEach { assert(script, contains: $0) }
    }

    func testSupabaseSchemaStaticCheckScriptCoversRLSGrantsIndexesAndSwiftParity() throws {
        let scriptURL = projectURL("Scripts/check_supabase_schema.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        [
            "20260717000100_create_remote_history_and_apple_auth_tokens.sql",
            "20260718000100_harden_history_constraints.sql",
            "20260718000200_harden_apple_auth_token_identity.sql",
            "20260722000100_create_marketplace_research_cache.sql",
            "20260724233029_early_access_entitlements.sql",
            "20260725001000_add_history_listing_metadata.sql",
            "20260725141629_add_history_identification_profile.sql",
            "BuySellAI/Data/Marketplace.swift",
            "BuySellAI/Data/Models.swift",
            "Postgres does not support ADD CONSTRAINT IF NOT EXISTS",
            "alter\\s+table\\s+public\\.{table}\\s+enable\\s+row\\s+level\\s+security",
            "alter\\s+table\\s+public\\.{table}\\s+force\\s+row\\s+level\\s+security",
            "select\\s+auth\\.uid\\(\\)",
            "history_user_created_at_idx",
            "apple_auth_tokens_apple_user_id_unique",
            "revoke all on table public.history from anon",
            "grant select, insert, update, delete on table public.history to authenticated",
            "revoke all on table public.apple_auth_tokens from authenticated",
            "apple_auth_tokens must not grant authenticated table access",
            "revoke all on table public.marketplace_research_cache from authenticated",
            "marketplace_research_cache must not grant authenticated table access",
            "for table in (\"entitlement_config\", \"entitlement_usage_events\")",
            "f\"{table} must not grant authenticated table access\"",
            "entitlement_usage_identity_day_idx",
            "entitlement_usage_user_day_idx",
            "entitlement_usage_device_day_idx",
            "entitlement_usage_ip_day_idx",
            "require_value_parity(\"category\"",
            "require_value_parity(\"condition\"",
            "require_value_parity(\"marketplace\"",
            "Supabase schema static check passed",
            "tables: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events",
            "rls: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events forced",
            "policy: history authenticated select-auth-uid",
            "indexes: history_user_created_at_idx apple_auth_tokens_apple_user_id_unique entitlement_usage_identity_day_idx entitlement_usage_user_day_idx entitlement_usage_device_day_idx entitlement_usage_ip_day_idx",
            "grants: history authenticated service_role apple_auth_tokens service_role marketplace_research_cache service_role entitlement_config service_role entitlement_usage_events service_role",
            "constraints: history category condition marketplace listing metadata identification-profile apple-token-identity marketplace-research-cache early-access-entitlements usage-protection",
            "swift parity: category condition marketplace",
        ].forEach { assert(script, contains: $0) }
    }

    func testSupabaseDeployHelperGuardsRemoteSchemaAndFunctionDeployment() throws {
        let scriptURL = projectURL("Scripts/deploy_supabase_backend.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "ALLOW_MISSING_SUPABASE_DEPLOY"))
        XCTAssertNotNil(script.range(of: "M10 Supabase deploy preflight pending"))
        XCTAssertNotNil(script.range(of: "CONFIRM_SUPABASE_DEPLOY"))
        XCTAssertNotNil(script.range(of: "Supabase CLI is required; install it, run supabase login, and link the project"))
        XCTAssertNotNil(script.range(of: "supabase/.temp/project-ref"))
        XCTAssertNotNil(script.range(of: "Scripts/setup_supabase_config.sh"))
        XCTAssertNotNil(script.range(of: "Scripts/setup_supabase_secrets.sh full"))
        XCTAssertNotNil(script.range(of: "SUPABASE_TELEMETRY_DISABLED"))
        XCTAssertNotNil(script.range(of: "M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS"))
        XCTAssertNotNil(script.range(of: "run_secret_list_with_timeout"))
        XCTAssertNotNil(script.range(of: "bash \"$repo_root/Scripts/check_supabase_schema.sh\""))
        XCTAssertNotNil(script.range(of: "bash \"$repo_root/Scripts/check_supabase_functions.sh\""))
        XCTAssertNotNil(script.range(of: "supabase/migrations/20260718000100_harden_history_constraints.sql"))
        XCTAssertNotNil(script.range(of: "supabase/migrations/20260718000200_harden_apple_auth_token_identity.sql"))
        XCTAssertNotNil(script.range(of: "supabase/migrations/20260722000100_create_marketplace_research_cache.sql"))
        XCTAssertNotNil(script.range(of: "supabase/migrations/20260724233029_early_access_entitlements.sql"))
        XCTAssertNotNil(script.range(of: "supabase/migrations/20260725001000_add_history_listing_metadata.sql"))
        XCTAssertNotNil(script.range(of: "supabase/migrations/20260725141629_add_history_identification_profile.sql"))
        XCTAssertNotNil(script.range(of: "supabase secrets list --project-ref \"$project_ref\" --output json"))
        XCTAssertNotNil(script.range(of: "Supabase secret names could not be listed within"))
        XCTAssertNotNil(script.range(of: "supabase db push --linked --yes"))
        XCTAssertNotNil(script.range(of: "supabase functions deploy \"$function_name\" --project-ref \"$project_ref\" --use-api"))
        XCTAssertNotNil(script.range(of: "M10 Supabase deploy passed"))
        XCTAssertNotNil(script.range(of: "M10 Supabase deploy preflight passed"))
        XCTAssertNotNil(script.range(of: "schema: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events"))
        XCTAssertNotNil(script.range(of: "constraints: history category condition marketplace listing metadata identification-profile apple-token-identity marketplace-research-cache early-access-entitlements usage-protection"))
        XCTAssertNotNil(script.range(of: "functions: %s"))
        XCTAssertNotNil(script.range(of: "secrets: required names present"))

        for value in [
            "GEMINI_API_KEY",
            "SUPABASE_SERVICE_ROLE_KEY",
            "APPLE_TEAM_ID",
            "APPLE_KEY_ID",
            "APPLE_CLIENT_ID",
            "APPLE_PRIVATE_KEY",
            "analyze-image",
            "generate-listing",
            "store-apple-token",
            "delete-account"
        ] {
            XCTAssertNotNil(script.range(of: value))
        }

        XCTAssertNil(script.range(of: "supabase secrets set"))
        XCTAssertNil(script.range(of: "GEMINI_API_KEY="))
        XCTAssertNil(script.range(of: "SUPABASE_SERVICE_ROLE_KEY="))
        XCTAssertNil(script.range(of: "APPLE_PRIVATE_KEY="))
    }

    func testSupabaseSecretSetupScriptKeepsProviderSecretsOutOfSourceAndAppConfig() throws {
        let scriptURL = projectURL("Scripts/setup_supabase_secrets.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let backendReadme = try String(contentsOf: projectURL("supabase/README.md"), encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "mktemp \"${TMPDIR:-/tmp}/buysell-supabase-secrets.XXXXXX\""))
        XCTAssertNotNil(script.range(of: "chmod 600 \"$secret_file\""))
        XCTAssertNotNil(script.range(of: "trap cleanup EXIT"))
        XCTAssertNotNil(script.range(of: "SUPABASE_SECRETS_FROM_ENV"))
        XCTAssertNotNil(script.range(of: "SUPABASE_PROJECT_REF"))
        XCTAssertNotNil(script.range(of: "SUPABASE_TELEMETRY_DISABLED"))
        XCTAssertNotNil(script.range(of: "M10_SUPABASE_SECRET_LIST_TIMEOUT_SECONDS"))
        XCTAssertNotNil(script.range(of: "resolve_project_ref"))
        XCTAssertNotNil(script.range(of: "preflight"))
        XCTAssertNotNil(script.range(of: "require_secret_access"))
        XCTAssertNotNil(script.range(of: "run_secret_list_with_timeout"))
        XCTAssertNotNil(script.range(of: "supabase secrets list --project-ref \"$project_ref\" --output json"))
        XCTAssertNotNil(script.range(of: "Supabase secret access unavailable within"))
        XCTAssertNotNil(script.range(of: "before entering secrets"))
        XCTAssertNotNil(script.range(of: "Supabase secret setup preflight passed"))
        XCTAssertNotNil(script.range(of: "BuySellAI/App/Config.plist"))
        XCTAssertNotNil(script.range(of: "supabase/.temp/project-ref"))
        XCTAssertNotNil(script.range(of: "SUPABASE_PROJECT_REF is required"))
        XCTAssertNotNil(script.range(of: "read_secret_or_env \"Gemini API key: \" GEMINI_API_KEY"))
        XCTAssertNotNil(script.range(of: "read_secret_or_env \"Supabase service-role key: \" SUPABASE_SERVICE_ROLE_KEY"))
        XCTAssertNotNil(script.range(of: "read_required_or_env \"Apple Team ID: \" APPLE_TEAM_ID"))
        XCTAssertNotNil(script.range(of: "read_required_or_env \"Apple native client ID / bundle ID: \" APPLE_CLIENT_ID"))
        XCTAssertNotNil(script.range(of: "read_required_or_env \"Apple private key .p8 path: \" APPLE_PRIVATE_KEY_PATH"))
        XCTAssertNotNil(script.range(of: "validate_apple_private_key_path"))
        XCTAssertNotNil(script.range(of: "APPLE_PRIVATE_KEY_PATH must point to a .p8 file outside the repository"))
        XCTAssertNotNil(script.range(of: "APPLE_PRIVATE_KEY_PATH must not point inside the repository"))
        XCTAssertNotNil(script.range(of: "APPLE_PRIVATE_KEY_PATH must point to a .p8 private-key file"))
        XCTAssertNotNil(script.range(of: "BEGIN PRIVATE KEY"))
        XCTAssertNotNil(script.range(of: "is required in environment when SUPABASE_SECRETS_FROM_ENV=1"))
        XCTAssertNotNil(script.range(of: "write_secret \"GEMINI_API_KEY\" \"$GEMINI_API_KEY\""))
        XCTAssertNotNil(script.range(of: "write_secret \"APPLE_PRIVATE_KEY\" \"$APPLE_PRIVATE_KEY\""))
        XCTAssertNotNil(script.range(of: "supabase secrets set --project-ref \"$project_ref\" --env-file \"$secret_file\""))
        XCTAssertNotNil(script.range(of: "project ref: %s"))
        XCTAssertNotNil(script.range(of: "gemini-only"))
        XCTAssertNotNil(script.range(of: "temporary secret file must not be inside the repository"))
        XCTAssertNotNil(script.range(of: "Never put"))
        XCTAssertNotNil(script.range(of: "Gemini, service-role, or Apple private-key material"))
        XCTAssertNil(script.range(of: "> .env"))
        XCTAssertNil(script.range(of: "GEMINI_API_KEY="))
        XCTAssertNil(script.range(of: "SUPABASE_SERVICE_ROLE_KEY="))

        for text in [readme, backendReadme] {
            XCTAssertNotNil(text.range(of: "Scripts/setup_supabase_secrets.sh preflight"))
            XCTAssertNotNil(text.range(of: "Scripts/setup_supabase_secrets.sh full"))
            XCTAssertNotNil(text.range(of: "0600 temporary env file outside the repository"))
            XCTAssertNotNil(text.range(of: "before any secret values are requested"))
            XCTAssertNotNil(text.range(of: "SUPABASE_SECRETS_FROM_ENV"))
            XCTAssertNotNil(text.range(of: "SUPABASE_PROJECT_REF"))
            XCTAssertNotNil(text.range(of: "supabase secrets set --project-ref <project-ref> --env-file"))
            XCTAssertNotNil(text.range(of: "outside the repository and must be a `.p8` private-key file"))
            XCTAssertNotNil(text.range(of: "CI secret environment variables"))
            XCTAssertNotNil(text.range(of: "SUPABASE_TELEMETRY_DISABLED=1"))
            XCTAssertNotNil(text.range(of: "gemini-only"))
            XCTAssertNotNil(text.range(of: "full App Store readiness still requires"))
        }
    }

    func testSupabaseAppConfigSetupScriptFeedsBackendPreflightWithoutProviderSecrets() throws {
        let scriptURL = projectURL("Scripts/setup_supabase_config.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)
        let backendReadme = try String(contentsOf: projectURL("supabase/README.md"), encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertNotNil(script.range(of: "CONFIG_PATH"))
        XCTAssertNotNil(script.range(of: "SUPABASE_CONFIG_FROM_ENV"))
        XCTAssertNotNil(script.range(of: "read_required_or_env \"Supabase project URL: \" supabase_url SUPABASE_URL"))
        XCTAssertNotNil(script.range(of: "read_required_or_env \"Supabase anon key: \" anon_key SUPABASE_ANON_KEY"))
        XCTAssertNotNil(script.range(of: "is required in environment when SUPABASE_CONFIG_FROM_ENV=1"))
        XCTAssertNotNil(script.range(of: "SUPABASE_URL must be a root https://<project>.supabase.co URL"))
        XCTAssertNotNil(script.range(of: "SUPABASE_URL still contains the Config.plist.example placeholder"))
        XCTAssertNotNil(script.range(of: "SUPABASE_ANON_KEY still contains the Config.plist.example placeholder"))
        XCTAssertNotNil(script.range(of: "SUPABASE_ANON_KEY looks like a provider/server-secret-shaped value"))
        XCTAssertNotNil(script.range(of: "keys: SUPABASE_URL SUPABASE_ANON_KEY"))
        XCTAssertNil(script.range(of: "printf 'SUPABASE_ANON_KEY"))

        for text in [readme, m10, backendReadme] {
            XCTAssertNotNil(text.range(of: "Scripts/setup_supabase_config.sh"))
            XCTAssertNotNil(text.range(of: "BuySellAI/App/Config.plist"))
            XCTAssertNotNil(text.range(of: "provider/server-secret-shaped values"))
        }
        XCTAssertNotNil(readme.range(of: "reads them from environment variables with the same names for noninteractive setup"))
        XCTAssertNotNil(readme.range(of: "SUPABASE_CONFIG_FROM_ENV"))
        XCTAssertNotNil(m10.range(of: "reads environment variables with the same names for noninteractive setup"))
        XCTAssertNotNil(m10.range(of: "SUPABASE_CONFIG_FROM_ENV=1"))
        XCTAssertNotNil(backendReadme.range(of: "reads environment variables with the same names for noninteractive setup"))
        XCTAssertNotNil(backendReadme.range(of: "SUPABASE_CONFIG_FROM_ENV=1"))
    }

    func testCombinedSubmitReadinessRequiresBackendPreflightLogAndDocsRouteThroughGate() throws {
        let script = try String(contentsOf: projectURL("Scripts/verify_m10_submit_readiness.sh"), encoding: .utf8)
        let readme = try String(contentsOf: projectURL("README.md"), encoding: .utf8)
        let m10 = try String(contentsOf: projectURL("M10_ACCEPTANCE.md"), encoding: .utf8)

        XCTAssertNotNil(script.range(of: "M10_BACKEND_LOG"))
        XCTAssertNotNil(script.range(of: "/tmp/buysell-submit-readiness-backend.log"))
        XCTAssertNotNil(script.range(of: "M10 backend preflight passed"))
        XCTAssertNotNil(script.range(of: "schema: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events"))
        XCTAssertNotNil(script.range(of: "functions: analyze-image compare-marketplaces generate-listing store-apple-token delete-account"))
        XCTAssertNotNil(script.range(of: "protected functions: store-apple-token delete-account"))
        XCTAssertNotNil(script.range(of: "protected tables: history apple_auth_tokens marketplace_research_cache entitlement_config entitlement_usage_events"))
        XCTAssertNotNil(script.range(of: "analyze rejection contract: missing jpeg base64"))
        XCTAssertNotNil(script.range(of: "listing contract: title-description-plain-text"))
        XCTAssertNotNil(script.range(of: "listing rejection contract: platform category condition"))
        XCTAssertNotNil(script.range(of: "backend preflight log"))
        XCTAssertNotNil(script.range(of: "M10BackendPreflightScriptTests/testBackendPreflightScriptValidatesConfigAndCallsRequiredSupabaseRoutes"))

        XCTAssertNotNil(readme.range(of: "Scripts/preflight_m10_backend.sh"))
        XCTAssertNotNil(readme.range(of: "Scripts/setup_supabase_config.sh"))
        XCTAssertNotNil(readme.range(of: "Scripts/check_supabase_functions.sh"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-submit-readiness-supabase-functions.log"))
        XCTAssertNotNil(readme.range(of: "ALLOW_MISSING_BACKEND=1"))
        XCTAssertNotNil(readme.range(of: "/tmp/buysell-submit-readiness-backend.log"))
        XCTAssertNotNil(m10.range(of: "Scripts/preflight_m10_backend.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/setup_supabase_config.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/check_supabase_functions.sh"))
        XCTAssertNotNil(m10.range(of: "Scripts/setup_supabase_secrets.sh full"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-supabase-functions.log"))
        XCTAssertNotNil(m10.range(of: "Run the M10 backend smoke preflight"))
        XCTAssertNotNil(m10.range(of: "/tmp/buysell-submit-readiness-backend.log"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    private func assert(
        _ text: String,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(text.range(of: expected), "Missing expected snippet: \(expected)", file: file, line: line)
    }
}
