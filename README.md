# BuySell AI iOS

Native SwiftUI rebuild of BuySell AI for iOS 17+.

## Open

Open `BuySellAI.xcodeproj` in Xcode 16.4 or newer.

The current local SDK is Xcode 16.4 with the iOS 18.5 SDK. The app's native material layer centralizes latest-iOS presentation behavior through `BuySellAI/Design/NativeMaterialSurface.swift` using `ultraThinMaterial` and `regularMaterial` as compiler-safe fallbacks while keeping compiler-gated iOS 26+ hooks for `glassEffect`, `GlassEffectContainer`, `GlassButtonStyle`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)` in the same wrapper. Home now uses a native `NavigationStack`, `.insetGrouped` `List`, large navigation title, toolbar account/settings actions, and row-based primary task affordances instead of the legacy floating hero artwork, pill stack, and glow treatment. Camera controls route through shared native material wrappers where the preview needs foreground legibility, and the Camera surface includes tap focus, camera switching, scene-phase recovery, and capture controls. Flow-sheet chrome, focused inputs, Settings row icons, chips, toasts, generated-listing panels, marketplace badges, and first-launch tutorial controls continue to route through shared native material wrappers where a material layer has a functional purpose. Auth setup uses native inset grouped rows and system bars instead of a custom material control cluster. `Info.plist` intentionally omits `UIDesignRequiresCompatibility` so iOS 26+ can use the current system presentation instead of design compatibility mode. Final M10 readiness requires `Scripts/verify_m10_latest_design_sdk.sh` to pass with an Xcode/iPhoneOS SDK 27+ latest-design toolchain by default; the Xcode 16.4 fallback evidence is not treated as the final App Store design proof.

On iOS 26+ builds, `nativeSystemSheetPresentationChrome()` leaves Auth and Settings sheet backgrounds to the native Liquid Glass presentation; on older SDK/runtime paths it preserves the current `.regularMaterial` fallback. The latest-design verifier records this as `system sheet background: iOS 26+ native Liquid Glass, regularMaterial fallback`.

Typography setup is guarded end to end: app screens use native San Francisco semantic Dynamic Type roles directly, the wordmark maps to semantic title roles with Bold Text-aware weights, `Info.plist` does not register runtime custom fonts, user-facing text avoids raw fixed-size font overrides, and SF Symbol sizing routes through shared `BrandSymbolStyle` tokens. Legacy Space Grotesk and Inter font assets have been removed so the synchronized app target cannot bundle obsolete custom typefaces.

To connect the real Supabase backend, write the app-side public config with:

```sh
bash Scripts/setup_supabase_config.sh
```

The helper prompts for these values, or reads them from environment variables with the same names for noninteractive setup. Set `SUPABASE_CONFIG_FROM_ENV` to `1` on CI/release machines so missing public config values fail fast instead of prompting:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` containing the public anon key or `sb_publishable_...` publishable key

It writes only those public keys to `BuySellAI/App/Config.plist`, rejects copied placeholders and provider/server-secret-shaped values, and never prints the anon key. `Config.plist` is git-ignored.

Keep AI provider secrets, Supabase `sb_secret_...` keys, JWT signing secrets, service-role keys, and Apple private-key material out of the iOS bundle. Add them to Supabase Edge Function or project secret storage instead, using the variable names expected by the deployed functions, then let the app call the existing `analyze-image` and `generate-listing` functions through Supabase. Rotate any provider or server-side key that was pasted into chat, logs, or git before using it for production. The bundled config parser accepts only `SUPABASE_URL` and `SUPABASE_ANON_KEY` and rejects provider/server-secret-shaped values.

Current submit-readiness state: the local, git-ignored `BuySellAI/App/Config.plist` is configured for Supabase project `czuoebqjajupghivqkch` with a public publishable key. No linked project file exists under `supabase/.temp/`, and live deploy/smoke evidence still requires Supabase CLI access, server-side secrets, deployed migrations, deployed functions, and a retained sample image. The Gemini key, Supabase `sb_secret_...` key, JWT secret, service-role key, and Apple private-key material must be set only through the server-side secret helpers or Supabase dashboard; they must not be copied into `Config.plist`, source, tests, README examples, or shell history.

Deployable Supabase Edge Function templates live in `supabase/functions/` for the app's `analyze-image`, `generate-listing`, `store-apple-token`, and `delete-account` routes. They preserve the native iOS contracts while keeping `GEMINI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and Sign in with Apple private-key material server-side.

Safe secret setup for the existing Edge Functions:

```sh
SUPABASE_PROJECT_REF=<project-ref> bash Scripts/setup_supabase_secrets.sh preflight
SUPABASE_PROJECT_REF=<project-ref> bash Scripts/setup_supabase_secrets.sh full
```

The `preflight` mode resolves the target project and verifies Supabase CLI secret access before any secret values are requested. The `full` helper prompts for `GEMINI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID`, and an Apple private-key `.p8` path, or reads those values from CI secret environment variables when `SUPABASE_SECRETS_FROM_ENV` is set to `1`. It resolves the target from `SUPABASE_PROJECT_REF`, `BuySellAI/App/Config.plist`, or the linked Supabase project before prompting for secrets, validates that the Apple private-key path resolves outside the repository and must be a `.p8` private-key file, writes a 0600 temporary env file outside the repository, calls `supabase secrets set --project-ref <project-ref> --env-file`, and removes the temp file on exit. The Supabase release helpers default `SUPABASE_TELEMETRY_DISABLED=1` so CLI telemetry cannot make release checks flaky. Use `SUPABASE_PROJECT_REF=<project-ref> bash Scripts/setup_supabase_secrets.sh gemini-only` only for an early guest analyze/listing smoke test; full App Store readiness still requires the service-role and Apple secrets. Do not paste provider or server-side secrets into `Config.plist`, Xcode build settings, source files, test fixtures, or shell commands that would remain in history.

Apple Developer account state: team `RHODES MCALLEN COONS COONS` (`ZVFG6KC7KA`) is selected in the Xcode project for Bundle ID `com.despia.buysellai`. Sign in with Apple is still pending in Apple Developer because the App ID capability is not enabled, no Services ID exists, and no Sign in with Apple key has been created. Complete these Apple-side steps before full auth release evidence:

- Enable Sign in with Apple on App ID `com.despia.buysellai` as the primary App ID.
- Register Services ID `com.despia.buysellai.signin`, configure domain `czuoebqjajupghivqkch.supabase.co`, and set return URL `https://czuoebqjajupghivqkch.supabase.co/auth/v1/callback`.
- Create a Sign in with Apple key, associate it with `com.despia.buysellai`, download the `.p8` once, and record the Key ID.
- In Supabase Auth's Apple provider, enable Apple and list `com.despia.buysellai.signin` first in Client IDs, with `com.despia.buysellai` also listed for native token audiences.
- For this app's `store-apple-token` Edge Function, set `APPLE_TEAM_ID=ZVFG6KC7KA`, `APPLE_CLIENT_ID=com.despia.buysellai`, the new `APPLE_KEY_ID`, and the `.p8` content through `Scripts/setup_supabase_secrets.sh full` or equivalent server-side secret storage.

Optional backend tuning:

```sh
# Optional: override the stable production default only after collecting fresh release evidence.
supabase secrets set GEMINI_MODEL=gemini-2.5-flash
supabase secrets set GEMINI_TIMEOUT_MS=18000
supabase secrets set APPLE_TIMEOUT_MS=8000
supabase secrets set SUPABASE_SERVICE_TIMEOUT_MS=8000
```

`GEMINI_MODEL` defaults to Google's stable `gemini-2.5-flash` model so App Store evidence is repeatable while keeping listing research fast and low-cost. The `generate-listing` function plans at most three marketplace research questions, reuses fresh rows from `marketplace_research_cache`, and only enables live Google Search/URL context when saved research is missing or stale. Override the model only for a deliberate model change, then rerun the backend smoke preflight, Deno check, unit/UI evidence, and M10 submit-readiness gate before submission.

Apply the bundled Supabase schema migration from `supabase/migrations/` before deploying functions:

```sh
supabase db push
```

The migrations create the signed-in `history` table, harden it with native value/listing constraints, and create the private `apple_auth_tokens` table with RLS, least-privilege grants, and unique Apple subject storage. To check the deployment inputs without making remote changes:

```sh
ALLOW_MISSING_SUPABASE_DEPLOY=1 bash Scripts/deploy_supabase_backend.sh preflight
```

After `Scripts/setup_supabase_config.sh`, `SUPABASE_PROJECT_REF=<project-ref> bash Scripts/setup_supabase_secrets.sh full`, and `supabase link --project-ref <project-ref>` are complete, deploy the schema and functions with:

```sh
CONFIRM_SUPABASE_DEPLOY=<project-ref> bash Scripts/deploy_supabase_backend.sh deploy | tee /tmp/buysell-submit-readiness-supabase-deploy.log
```

The deploy helper validates the public app config, linked project, required server-side secret names, migrations, and Edge Function sources, then runs `supabase db push --linked --yes` and deploys each function with `--use-api`. It never prints secret values. Passing deploy evidence includes `constraints: history category condition marketplace listing apple-token-identity marketplace-research-cache`. Manual equivalent commands are:

```sh
supabase functions deploy analyze-image
supabase functions deploy generate-listing
supabase functions deploy store-apple-token
supabase functions deploy delete-account
```

Local Supabase schema static check:

```sh
bash Scripts/check_supabase_schema.sh | tee /tmp/buysell-submit-readiness-supabase-schema.log
```

The schema checker verifies the migration files without connecting to Supabase. It checks forced RLS on `history`, `apple_auth_tokens`, and `marketplace_research_cache`, the cached `(select auth.uid())` authenticated history policy, RLS/filter indexes, least-privilege grants, idempotent hardening constraints, unique Apple subject storage, service-only marketplace research storage, and parity between the Swift `Category`, `Condition`, and `Marketplace` raw values and the SQL check constraints. Passing output includes `Supabase schema static check passed`, `tables: history apple_auth_tokens marketplace_research_cache`, `rls: history apple_auth_tokens marketplace_research_cache forced`, `policy: history authenticated select-auth-uid`, `indexes: history_user_created_at_idx apple_auth_tokens_apple_user_id_unique`, `grants: history authenticated service_role apple_auth_tokens service_role marketplace_research_cache service_role`, `constraints: history category condition marketplace listing apple-token-identity marketplace-research-cache`, and `swift parity: category condition marketplace`. Retain the log for the combined M10 gate; it is local schema evidence and does not replace `supabase db push`, deploy evidence, or the live backend smoke preflight.

Signed-in history sync expects the migrated PostgREST `history` table protected by RLS:

```sql
create table public.history (
  id uuid primary key,
  user_id uuid not null default auth.uid(),
  created_at timestamptz not null,
  item_name text not null,
  category text,
  condition text,
  suggested_price numeric,
  image_thumbnail_base64 text,
  marketplace text not null,
  listing_text text not null,
  constraint history_item_name_not_blank check (btrim(item_name) <> ''),
  constraint history_marketplace_not_blank check (btrim(marketplace) <> ''),
  constraint history_listing_text_not_blank check (btrim(listing_text) <> ''),
  constraint history_suggested_price_positive check (suggested_price is null or suggested_price > 0)
);

create index history_user_created_at_idx
on public.history (user_id, created_at desc);

alter table public.history enable row level security;
alter table public.history force row level security;

create policy "Users can manage their own history"
on public.history
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
```

The follow-up hardening migrations add `history_category_known`, `history_condition_known`, `history_marketplace_known`, and `history_listing_text_has_sections` constraints so signed-in history rows stay aligned with the native `Category`, `Condition`, `Marketplace`, and generated listing contracts. They also add `apple_auth_tokens_apple_user_id_unique` so private Apple token storage cannot duplicate a Sign in with Apple subject across account rows.

Sign in with Apple token revocation expects the migrated private service-role-only table:

```sql
create table public.apple_auth_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  apple_user_id text not null,
  refresh_token text not null,
  access_token text,
  access_token_expires_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint apple_auth_tokens_apple_user_id_unique unique (apple_user_id)
);

alter table public.apple_auth_tokens enable row level security;
```

Account deletion calls a Supabase Edge Function:

```txt
POST /functions/v1/delete-account
Authorization: Bearer <supabaseAccessToken>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{}
```

The `store-apple-token` function verifies the bearer token, checks whether the Apple subject is already owned by another Supabase user before exchanging the one-time Apple code, requires Apple's token response subject to match the submitted Apple user ID, and returns a 409 conflict instead of hiding duplicate identity storage behind a generic server error. The delete function verifies the bearer token, attempts to revoke stored Sign in with Apple tokens through Apple's `/auth/revoke` endpoint when present, deletes the private token row and user-owned data covered by RLS, then deletes the auth user server-side with privileged credentials. BuySell account deletion still completes if Apple token cleanup is stale or temporarily unavailable, but missing or malformed Apple private-key secrets remain hard backend errors so release evidence cannot hide a revocation misconfiguration.

## Verify

```sh
xcodebuild test \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
```

Release archive compile/package check:

```sh
bash Scripts/verify_m10_local_archive.sh /tmp/buysell-submit-readiness-nosign.xcarchive
```

If Xcode stalls while loading the project from the full checkout, run the no-sign archive check from a lean iOS snapshot:

```sh
M10_LOCAL_ARCHIVE_SNAPSHOT_ROOT=/tmp/buysell-m10-archive-worktree \
bash Scripts/verify_m10_local_archive.sh /tmp/buysell-submit-readiness-nosign.xcarchive
```

Signed archive preflight:

```sh
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_signed_archive.sh /tmp/BuySellAI-signed.xcarchive \
  | tee /tmp/buysell-submit-readiness-signed-preflight.log
```

If Xcode stalls while loading the project from the full checkout, run the signed archive preflight from a lean iOS snapshot:

```sh
M10_SIGNED_ARCHIVE_SNAPSHOT_ROOT=/tmp/buysell-m10-signed-worktree \
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_signed_archive.sh /tmp/BuySellAI-signed.xcarchive \
  | tee /tmp/buysell-submit-readiness-signed-preflight.log
```

App Store Connect export preflight:

```sh
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_app_store_export.sh /tmp/BuySellAI-appstore.xcarchive /tmp/BuySellAI-appstore-export \
  | tee /tmp/buysell-submit-readiness-export-preflight.log
```

If Xcode stalls while loading the project from the full checkout, run the App Store export preflight from a lean iOS snapshot:

```sh
M10_APP_STORE_EXPORT_SNAPSHOT_ROOT=/tmp/buysell-m10-appstore-export-worktree \
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_app_store_export.sh /tmp/BuySellAI-appstore.xcarchive /tmp/BuySellAI-appstore-export \
  | tee /tmp/buysell-submit-readiness-export-preflight.log
```

App Store Connect validation preflight after export and API-key setup:

```sh
ASC_API_KEY_ID=<key-id> \
ASC_API_ISSUER_ID=<issuer-id> \
ASC_API_PRIVATE_KEYS_DIR=<directory-containing-AuthKey_key-id.p8> \
bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export \
  | tee /tmp/buysell-submit-readiness-app-store-validation-preflight.log
```

App Store Connect metadata evidence after product-page metadata, screenshots, privacy/support/accessibility URLs, app privacy answers, Accessibility Nutrition Labels, age rating, DSA status, account-owner legal confirmation, and review notes are recorded:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

The metadata verifier checks concrete App Store Connect fields, unauthenticated public HTTPS privacy/support/accessibility URLs, screenshot evidence, account-owner legal confirmation, review notes, the 100-byte keyword limit, privacy answers matching `PrivacyInfo.xcprivacy`, and Accessibility Nutrition Label evidence for the claimed iPhone/iPad accessibility features and common tasks. It rejects assumption, pending, and confirm-before-submission wording in legal/account-owner fields. It also verifies the retained PNG screenshot files exist for the required iPhone 6.9-inch and iPad 13-inch display classes, match `1320x2868` and `2064x2752` dimensions, pass blank/dark-strip artifact checks, and came from retained xcresults where `testM10AppStoreScreenshotsCanBeCaptured()` passed. Passing logs include `file:`, `app name:`, `bundle id:`, `version:`, `privacy policy:`, `support:`, `accessibility url:`, `screenshots:`, `legal:`, `screenshot sets:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot quality:`, `screenshot result bundle:`, `screenshot capture test:`, `app privacy:`, `accessibility labels:`, and `accessibility evidence:` markers. Retain the passing output as `/tmp/buysell-submit-readiness-app-store-metadata.log` for the combined gate. Allowed-pending output still emits the recorded evidence markers, but keeps the legal/account-owner blocker visible. Until those fields are complete, record the known blocker:

Screenshot metadata logs also include `screenshot brand signal: warm orange present`, proving the retained App Store screenshots carry the BuySell orange visual signal.

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

The App Store support/privacy/accessibility site source lives in `AppStoreSite/`. Sites version 7 was saved from support-site commit `14d6355e7a28484c513ecee29487602c18c21c6b` and deployed at `https://buysell-ai-support.o5hinwavve.chatgpt.site`; site access is public, and unauthenticated home, support, privacy, accessibility, and terms requests return `200` in `/tmp/buysell-support-site-live.log`. A fresh `npm run build` in `AppStoreSite/` now clears stale local Wrangler deploy state, rebuilds the Vinext/Sites output, validates fresh `dist/server/index.js`, `dist/client`, and `dist/.openai/hosting.json` output, and renders `/`, `/support`, `/privacy`, `/accessibility`, and `/terms` before printing `BuySell support site build passed`; retain `/tmp/buysell-support-site-build.log`, `/tmp/buysell-support-site-test.log`, and `/tmp/buysell-support-site-live.log` as support-site evidence. The iOS Settings legal links use the same Sites host, so the App Store Support URL, Privacy Policy URL, and Accessibility URL fields point at the public `/support`, `/privacy`, and `/accessibility` pages. Required App Store screenshot evidence is retained in `AppStoreAssets/Screenshots/iPhone-16-Pro-Max/` and `AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/` from passing simulator captures. Metadata assumptions recorded for App Store Connect are age rating `4+`, DSA status `Not a trader`, and copyright `2026 Rhodes`; the verifier intentionally keeps metadata pending until those assumptions are replaced by concrete App Store Connect account-owner confirmation.

Apple Today/App Store editorial nomination package:

```sh
bash Scripts/verify_m10_today_feature_nomination.sh M10_TODAY_FEATURE_NOMINATION.md \
  | tee /tmp/buysell-submit-readiness-today-feature.log
```

The Today feature verifier checks `M10_TODAY_FEATURE_NOMINATION.md` for Apple guidance links, the App Store Connect Featuring Nominations path, the two-week minimum and three-month wider-consideration lead-time note, eligible App Store Connect roles, concrete launch-story copy, native technology/accessibility/privacy angles, retained iPhone 6.9-inch and iPad 13-inch screenshot assets, public support/privacy/accessibility URL references, and the text-free 1024x1024 App Store icon. Passing logs include `M10 Today feature nomination package passed`, `file:`, `placement:`, `story:`, `lead time:`, `role:`, `assets:`, and `source:` markers; retain the output as `/tmp/buysell-submit-readiness-today-feature.log` for the combined gate. It proves the nomination package is ready to submit after the signed binary, App Store metadata, backend, real-device, and legal gates are complete; Apple editorial placement remains discretionary.

Backend smoke preflight after `Config.plist`, the migrated Supabase schema, the deployed Edge Functions, and a retained JPEG sample are available:

```sh
bash Scripts/setup_supabase_config.sh

M10_ANALYZE_IMAGE_JPEG=/path/to/common-item.jpg \
bash Scripts/preflight_m10_backend.sh BuySellAI/App/Config.plist
```

Type-check the local Supabase Edge Function sources before deploying them:

```sh
bash Scripts/check_supabase_functions.sh | tee /tmp/buysell-submit-readiness-supabase-functions.log
```

The Deno checker uses a local `deno` binary when available, or a temporary `npx --yes deno` fallback with `DENO_DIR` outside the repo. Passing output includes `Supabase function Deno check passed` and `functions: analyze-image generate-listing store-apple-token delete-account`. Retain the passing output as `/tmp/buysell-submit-readiness-supabase-functions.log` for the combined gate.

The backend preflight reads only the public Supabase URL and anon/publishable key from `Config.plist`; it does not print the key or any provider/server-side secret. The app and preflight both reject copied `Config.plist.example` placeholders before making backend requests. It verifies `analyze-image` and `generate-listing` with live responses, including the plain-text `TITLE:` and `DESCRIPTION:` listing contract, then verifies `analyze-image` rejects missing image data, non-JPEG data URLs, and malformed base64 while `generate-listing` rejects unsupported platform, category, and condition values. It then probes `store-apple-token` and `delete-account` to confirm the protected account functions are deployed and reject anonymous requests. It also probes the migrated `history`, `apple_auth_tokens`, and `marketplace_research_cache` PostgREST tables to confirm the schema is deployed and rejects anonymous reads. Passing logs include `config:`, `project:`, `schema: history apple_auth_tokens marketplace_research_cache`, `functions: analyze-image generate-listing store-apple-token delete-account`, `protected functions: store-apple-token delete-account`, `protected tables: history apple_auth_tokens marketplace_research_cache`, `analyze item:`, `analyze rejection contract: missing jpeg base64`, `listing contract:`, `listing rejection contract: platform category condition`, and `listing bytes:` markers. Retain the passing output as `/tmp/buysell-submit-readiness-backend.log` for the combined gate. Until the real deployed schema/functions and sample image are available, record the known blocker:

```sh
ALLOW_MISSING_BACKEND=1 bash Scripts/preflight_m10_backend.sh
```

`M10_DEVELOPMENT_TEAM` lets local release preflights use a personal Apple Team ID without committing it to the Xcode project. You can also select the team in Xcode instead. The signing, export, and real-device preflights bound the `xcodebuild -showBuildSettings` probe with `M10_XCODEBUILD_SETTINGS_TIMEOUT` (default `60` seconds); raise it only after confirming the checkout is fully local and Xcode is responsive.

Until the Apple team, exported IPA, and App Store Connect API-key credentials are available, record the known blockers:

```sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_signed_archive.sh \
  | tee /tmp/buysell-submit-readiness-signed-preflight.log
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_app_store_export.sh \
  | tee /tmp/buysell-submit-readiness-export-preflight.log
ALLOW_MISSING_ASC=1 bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export \
  | tee /tmp/buysell-submit-readiness-app-store-validation-preflight.log
```

Real-device preflight after connecting a trusted iPhone or iPad with Developer Mode enabled:

```sh
M10_DEVELOPMENT_TEAM=<team-id> bash Scripts/preflight_m10_real_device.sh \
  | tee /tmp/buysell-submit-readiness-real-device-preflight.log
```

If Xcode stalls while loading the project from the full checkout, run the real-device preflight from a lean iOS snapshot:

```sh
M10_REAL_DEVICE_SNAPSHOT_ROOT=/tmp/buysell-m10-real-device-worktree \
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_real_device.sh \
  | tee /tmp/buysell-submit-readiness-real-device-preflight.log
```

To target a specific connected device:

```sh
M10_DEVELOPMENT_TEAM=<team-id> DEVICE_ID=<devicectl-identifier> bash Scripts/preflight_m10_real_device.sh \
  | tee /tmp/buysell-submit-readiness-real-device-preflight.log
```

The preflight ignores non-iOS `devicectl` entries. A supplied `DEVICE_ID` must match a connected iPhone or iPad. Passing logs include `device:`, `device name:`, `device id:`, optional `snapshot root:`, `app:`, `bundle id:`, `sign in with apple:`, and `release build:` markers so final acceptance and Instruments metadata can point back to the same trusted device and Release build.

Until a trusted physical device is connected, record the known hardware blocker:

```sh
ALLOW_MISSING_DEVICE=1 bash Scripts/preflight_m10_real_device.sh \
  | tee /tmp/buysell-submit-readiness-real-device-preflight.log
```

Real-device acceptance evidence check after the manual device pass:

```sh
bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Each real-device acceptance Evidence cell must include the observed proof terms documented in `M10_ACCEPTANCE.md`; generic "passed" notes are intentionally rejected. Metadata is validated too: use a `YYYY-MM-DD` date, an iPhone or iPad device model that includes the real-device preflight `device name:` value, numeric iOS and release-build values, release-build metadata matching the signed-preflight `release build:` marker before final submit-readiness, signed-archive wording with the signed-preflight `archive:` path, signed archive validation proof from Xcode Organizer with that same `archive:` path, and App Store validation proof.

Until the manual device pass is complete, record the known acceptance blocker:

```sh
ALLOW_PENDING_ACCEPTANCE=1 bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Secret-pattern scan:

```sh
bash Scripts/scan_m10_secrets.sh
```

The scan prints both `M10 secret scan self-test passed` and `M10 secret scan passed`; retain that output in the M10 secret-scan log.

Local source typecheck when `xcodebuild` project loading is slow or blocked:

```sh
Scripts/typecheck_local_sources.sh | tee /tmp/buysell-local-source-typecheck.log
```

This first emits a non-DEBUG `BuySellAIRelease` Swift module from all app sources so release builds cannot reference UI-test sample fixtures, then emits a DEBUG `BuySellAI` module and typechecks the unit-test and UI-test Swift sources against the iPhone Simulator SDK and XCTest Swift overlay. Passing output includes `BuySellAI local source typecheck passed`, `target:`, `sdk:`, `sources: app unit ui`, and `modes: release app debug app unit ui`; retain it as `/tmp/buysell-local-source-typecheck.log` for the combined gate. It is fast source-level evidence only; it does not replace the retained `.xcresult` bundles, no-sign archive, signed archive, real-device, Supabase backend, or App Store validation gates.

Workspace materialization preflight for file-provider-backed checkouts:

```sh
bash Scripts/check_workspace_materialization.sh \
  | tee /tmp/buysell-submit-readiness-workspace-materialization.log
```

This verifies Git metadata, app sources, tests, Supabase sources, support-site sources, retained screenshots, and M10 docs are locally readable before the heavier Xcode and readiness checks run. Passing output includes `M10 workspace materialization passed`; use `ALLOW_DATALLESS_WORKSPACE=1` only to record a visible pending blocker while cloud-only files download.

Chunked M10 UI runner for isolating simulator UI failures or Xcode result-bundle hangs:

```sh
bash Scripts/run_m10_ui_tests.sh
```

The runner executes every `BuySellAIUITests` test in its own non-parallel `xcodebuild` invocation, writes one `.xcresult` and `.log` per test, and retains the rollup at `/tmp/buysell-m10-ui-tests/summary.log`. It retries simulator launch/preflight/install-worker infrastructure failures once by default (`M10_UI_MAX_ATTEMPTS=2`) while still failing immediately for app assertions; use `M10_UI_CONTINUE_ON_FAILURE=1 bash Scripts/run_m10_ui_tests.sh` to collect all failures in one pass. This is resumable UI evidence and does not replace the full-suite result bundle required by the performance and combined submit-readiness gates.

If Xcode project loading stalls while the checkout sits in a coordinated folder such as `Documents`, run the same evidence through a lean iOS snapshot:

```sh
M10_UI_SNAPSHOT_ROOT=/tmp/buysell-m10-ui-worktree bash Scripts/run_m10_ui_tests.sh
```

The snapshot mode copies the app, Xcode project, tests, scripts, Supabase sources, screenshot assets, and M10 docs into `/tmp`, skips support-site build artifacts such as `AppStoreSite/node_modules`, and writes normal result bundles/logs under `M10_UI_RESULT_ROOT`.

Chunked UI evidence verifier after the runner finishes:

```sh
bash Scripts/verify_m10_ui_evidence.sh \
  /tmp/buysell-m10-ui-tests \
  | tee /tmp/buysell-submit-readiness-ui.log
```

The verifier derives the current UI-test list from `BuySellAIUITests.swift`, checks the runner summary, verifies every per-test `.xcresult` reports one passing test, and retains `M10 UI evidence passed`, `summary:`, `result root:`, `tests:`, and per-test `test:` markers for the combined gate.

M10 performance evidence verifier after the full simulator suite and no-sign archive verifier finish:

```sh
bash Scripts/verify_m10_performance_evidence.sh \
  /tmp/buysell-submit-readiness-full.xcresult \
  /tmp/buysell-submit-readiness-nosign.log
```

M10 Instruments evidence verifier after profiling a signed Release build on trusted physical hardware:

```sh
bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

Each Instruments criteria Evidence cell must include the observed proof terms documented in `M10_INSTRUMENTS.md`; generic "passed" notes are intentionally rejected. Instruments metadata is validated too: use a `YYYY-MM-DD` date, an iPhone or iPad device model that includes the real-device preflight `device name:` value, numeric iOS and release-build values, signed-archive wording with the signed-preflight `archive:` path, and release-build metadata matching the signed-preflight `release build:` marker before final submit-readiness. The Time Profiler and Allocations trace metadata must point to retained files or directories, with relative paths resolved from the evidence file.

Until signed physical-device Instruments profiling is complete, record the known profiler blocker:

```sh
ALLOW_PENDING_INSTRUMENTS=1 bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

Latest-design SDK evidence gate:

```sh
bash Scripts/verify_m10_latest_design_sdk.sh
```

This verifier requires Xcode and the iPhoneOS SDK major version to be `27` or newer by default and confirms the shared native material wrapper contains compiler-gated iOS 26+ Liquid Glass hooks for `glassEffect`, `GlassEffectContainer`, `GlassButtonStyle`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)` while `Info.plist` omits `UIDesignRequiresCompatibility`. It also verifies obsolete primary, secondary, and ghost pill helpers plus their primary/standard background modifiers remain removed, active controls use iOS 26+ standard glass or restrained system/material fallbacks, Home uses a native inset grouped task list with toolbar account/settings actions, Camera controls preserve compiler-gated `GlassEffectContainer` support on iOS 26+, Auth uses native inset grouped sign-in rows with system bottom bars, Tutorial uses a concise first-use guide with one Start selling action, three native steps, keyboard dismissal, and no carousel pager, and Snap Result category/condition menus use SF Symbol rows with selected checkmarks. On the current Xcode 16.4/iOS 18.5 SDK machine, retain the known toolchain blocker log with:

```sh
ALLOW_MISSING_LIQUID_GLASS_SDK=1 bash Scripts/verify_m10_latest_design_sdk.sh > /tmp/buysell-submit-readiness-latest-design-sdk.log
```

Combined M10 submit-readiness evidence gate:

```sh
bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

The performance verifier carries forward the no-sign archive log's `bundle id:`, `release build:`, and `app size:` markers, and records each required simulator budget test as a `performance test:` marker. The combined gate expects retained artifact markers in the preflight logs and requires the local simulator result bundles, local source typecheck log, no-sign archive, no-sign verifier log, latest-design SDK evidence log, Today feature nomination log, Supabase schema static check log, Supabase function type-check log, secret-scan log, chunked UI evidence log, and performance evidence log to be fresh for the current HEAD commit; passing signed/App Store/Supabase deploy/backend/real-device/Instruments artifacts must be fresh too. It confirms the no-sign archive log retains the `app icon:`, `system design:`, `custom fonts:`, and `release fixtures:` markers, confirms the latest-design SDK log retains `M10 latest design SDK passed`, `xcode:`, `iphoneos sdk:`, `liquid glass sdk:`, `source:`, `source liquid glass:`, `obsolete button primitives:`, `active control glass:`, `home setup:`, `camera setup:`, `auth setup:`, `tutorial setup:`, `menu item icons:`, and `system sheet background:` markers, confirms the local source typecheck log retains `BuySellAI local source typecheck passed`, `target:`, `sdk:`, `sources: app unit ui`, and `modes: release app debug app unit ui` markers, confirms the App Store validation log references the same `ipa:` path produced by the export preflight, confirms the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `bundle id:` marker, confirms the signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `sign in with apple:` entitlement marker, confirms the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs record the same `release build:` value, confirms the App Store metadata log retains `app name:`, `bundle id:`, `privacy policy:`, `support:`, `accessibility url:`, `screenshots:`, `legal:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot quality:`, `screenshot result bundle:`, `screenshot capture test:`, `app privacy:`, `accessibility labels:`, and `accessibility evidence:` markers, confirms the Today feature nomination log retains `M10 Today feature nomination package passed`, `file:`, `placement:`, `story:`, `lead time:`, `role:`, `assets:`, and `source:` markers, confirms the secret-scan log retained the scanner self-test and repo-clean markers, confirms the chunked UI evidence log retains `M10 UI evidence passed` plus the runner summary and App Store screenshot UI test markers, confirms the performance evidence log retains the same no-sign archive `bundle id:` and `release build:` values plus every required simulator budget test name, confirms the Supabase deploy log retains `M10 Supabase deploy passed`, `config:`, `project:`, `project ref:`, `schema:`, `constraints:`, `functions:`, and `secrets:` markers, confirms the Supabase schema static check log retains `Supabase schema static check passed`, `tables:`, `rls:`, `policy:`, `indexes:`, `grants:`, `constraints:`, and `swift parity:` markers, confirms the Supabase function type-check log retains `Supabase function Deno check passed` plus every deployed function entrypoint, and confirms the backend preflight log proves the live migrated `history` and `apple_auth_tokens` tables plus the `analyze-image`, `generate-listing`, `store-apple-token`, and `delete-account` Edge Functions, including the live analyze rejection contract, plain-text listing contract, and unsupported listing-value rejection contract, without exposing secrets. The combined gate also confirms the Supabase deploy log and backend preflight log use the same `project:` marker, and confirms the manual acceptance and Instruments metadata reference the real-device preflight `device name:` value and signed-preflight `archive:` path while acceptance also references signed archive validation proof from Xcode Organizer and the validated `ipa:` path. The manual acceptance and Instruments evidence must also record matching iOS version and release build metadata for the same physical-device pass, and that release build must match the signed-preflight `release build:` marker. If you use non-default artifact paths, set the matching environment variables before running it: `M10_SOURCE_TYPECHECK_LOG`, `M10_NOSIGN_ARCHIVE`, `M10_LATEST_DESIGN_SDK_LOG`, `M10_SIGNED_ARCHIVE`, `M10_APP_STORE_ARCHIVE`, `M10_APP_STORE_EXPORT`, `M10_APP_STORE_METADATA`, `M10_APP_STORE_METADATA_LOG`, `M10_TODAY_FEATURE_NOMINATION`, `M10_TODAY_FEATURE_LOG`, `M10_BACKEND_LOG`, `M10_SUPABASE_DEPLOY_LOG`, `M10_SUPABASE_SCHEMA_CHECK_LOG`, `M10_SUPABASE_FUNCTION_CHECK_LOG`, `M10_UI_EVIDENCE_LOG`, and `M10_INSTRUMENTS_EVIDENCE`.

The combined gate also requires the App Store metadata log's `screenshot brand signal: warm orange present` marker and the Today feature nomination log's Apple source, placement, lead-time, role, story, and asset markers. It requires a clean git worktree, so every release source, screenshot, script, and evidence-document change must be committed or intentionally stashed before final submit-readiness can pass.

The combined gate checks a retained unit test suite result bundle; the current default evidence is `/tmp/buysell-full-unit-tests.xcresult` with `477` passing unit-target tests. If a newer refreshed unit bundle is collected, set `M10_UNIT_XCRESULT` and `M10_MIN_UNIT_TESTS` to that concrete artifact and count before running the gate.

Until every latest-design SDK, signed archive, App Store metadata/submission, backend, real-device, and manual evidence item is complete, record the known readiness blocker:

```sh
ALLOW_PENDING_M10=1 bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

The no-sign archive verifier validates the Release iPhoneOS build, text-free camera-first 1024x1024 non-alpha source App Store icon plus archived iPhone/iPad icon PNGs, the archived `Info.plist` current-system design marker with no `UIDesignRequiresCompatibility`, privacy manifest content, privacy/package metadata, camera capture plus read-only photo import permissions, the archived executable's absence of UI-test sample fixture markers with `release fixtures: none bundled`, and the `<20 MB` app bundle target. The latest-design SDK verifier is separate and must pass with Xcode/iPhoneOS SDK 27+ by default before final submit-readiness. A fully signed App Store archive, App Store Connect IPA export, and App Store Connect validation still require Apple portal Sign in with Apple setup and App Store Connect API-key credentials.

Track final signed-archive and real-device acceptance in `M10_ACCEPTANCE.md`. The final `Result Log` must include a complete `Pass` row with concrete Date, Tester, Device, iOS, Backend, Result, and Notes fields before the combined submit-readiness gate can pass. At least one Pass row must match the recorded Date, Tester, Device model, iOS version, and Backend project metadata. The Notes field must mention the signed archive, Xcode Organizer signed archive validation, App Store validation, real-device acceptance, and Instruments evidence used for the pass.

## Assumptions

- Supabase project values were not present in the blank repository. The API client is implemented against the requested `analyze-image` and `generate-listing` contracts, and the app shows friendly configuration errors until `Config.plist` is supplied.
- Supabase Auth must have Apple enabled for full server-backed Sign in with Apple. Without backend config, Apple sign-in shows a friendly configuration error; guest mode still leaves history local.
- The active app typography uses San Francisco system Dynamic Type roles directly; legacy custom font files have been removed and are not registered through `UIAppFonts`.
- Sign in with Apple has a native nonce-based coordinator, Supabase token exchange, server-side Apple token storage through `store-apple-token`, Keychain persistence, signed-in remote history sync, and guest-to-account migration. Delete account is wired to a `delete-account` Edge Function that attempts Apple token revocation, removes the private token row and history, then deletes the Supabase auth user; the backend functions and secrets still need to be deployed.
- `Config.plist.example` is kept in the repo for setup instructions but excluded from the app target so placeholder backend values are not shipped in the bundle.
- Real-device camera latency, Accessibility Inspector contrast checks, latest-design SDK verification without `ALLOW_MISSING_LIQUID_GLASS_SDK=1`, signed App Store archive validation, the signed-archive and App Store export preflights without `ALLOW_MISSING_TEAM=1`, the App Store validation preflight without `ALLOW_MISSING_ASC=1`, App Store Connect account-owner legal field confirmation, the backend smoke preflight without `ALLOW_MISSING_BACKEND=1`, the real-device preflight without `ALLOW_MISSING_DEVICE=1`, the real-device acceptance evidence check without `ALLOW_PENDING_ACCEPTANCE=1`, the Instruments evidence check without `ALLOW_PENDING_INSTRUMENTS=1`, and the combined submit-readiness gate without `ALLOW_PENDING_M10=1` still need physical-device/account QA. The performance evidence verifier covers only repeatable simulator and package-size evidence; final Time Profiler and Allocations evidence is tracked separately in `M10_INSTRUMENTS.md`.

## Milestone Status

- M1 Skeleton: built. Xcode project, design tokens, typography, launch screen, Home shell.
- M2 Camera: built. AVCapture preview, permission handling, torch, capture, downscale.
- M3 Analyze: built. API client contract, loading/success/error result sheet, inline editing.
- M4 Marketplace picker: built. Full marketplace list, metadata, fee table, estimator, sticky summary.
- M5 Listing: built. API contract, listing sheet, copy, haptics, toast.
- M6 History: built. SwiftData guest persistence, Home list, delete, reopen listing.
- M7 Auth: built. Native optional auth UI, Apple sign-in token exchange, Keychain persistence, signed-in remote history sync, and guest-to-account migration.
- M8 Tutorial: built. First launch uses a concise native first-use guide with Skip, one Start selling action, three clear selling steps, keyboard dismissal, and no carousel pager.
- M9 Settings + polish: built. Theme, app-wide reduce motion, history clearing, once-per-version review prompt gating, about links, account actions.
- M10 QA: partial. Simulator unit/UI coverage, source checks, no-sign archive/package-size checks, Supabase source guardrails, screenshot evidence, and local submit-readiness scripts have passed in retained evidence, but the full App Store gate remains pending external inputs. The current M11 redesign work updates those guardrails as screens move to the first-party system direction. Signed archive, App Store Connect export/validation, App Store Connect legal/account-owner confirmation, backend smoke preflight, latest-SDK proof, Instruments proof, and real-device acceptance remain blocked until Apple portal Sign in with Apple setup, App Store Connect API-key credentials, confirmed metadata, deployed real Supabase config/functions, a latest design SDK toolchain, and trusted physical hardware are available.

A signed archive, App Store Connect IPA export, App Store Connect validation, App Store Connect legal/account-owner confirmation, backend smoke preflight, and Instruments pass are blocked until Apple portal Sign in with Apple setup, App Store Connect API-key credentials, confirmed account-owner/product-page metadata, deployed real Supabase config/functions, and trusted physical hardware are available; real-device acceptance pass remains blocked until the acceptance evidence table is recorded.
