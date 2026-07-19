# M10 Acceptance Checklist

This checklist tracks the remaining submit-readiness work for BuySell AI iOS. Simulator tests and no-sign archives are useful evidence, but v1 is not complete until the signed archive and real-device checks below are recorded.

## Current Evidence

- Simulator suite: `469` unit/UI tests pass on iPhone 16 Pro simulator, iOS 18.6, from the current full-suite result bundle `/tmp/buysell-submit-readiness-full.xcresult`.
- Unit target: `389` `BuySellAITests` tests pass on iPhone 16 Pro simulator, iOS 18.6, in the retained default unit bundle `/tmp/buysell-full-unit-tests-9.xcresult`.
- Chunked simulator UI evidence: all `32` `BuySellAIUITests` tests pass through `Scripts/run_m10_ui_tests.sh`, with the rollup retained at `/tmp/buysell-m10-ui-tests/summary.log` and per-test `.xcresult`/`.log` artifacts under `/tmp/buysell-m10-ui-tests/`.
- Focused M10 guardrail slice: `464` tests pass on iPhone 16 Pro simulator, iOS 18.6, from `/tmp/buysell-submit-readiness-focused.xcresult`, including the required M10 script, metadata, Today nomination, backend, signing, performance, UI-evidence, and real-device guardrails.
- No-sign Release iPhoneOS archive: compiles and packages a `4812KB` app bundle from the lean snapshot worktree `/private/tmp/buysell-m10-archive-worktree`; refreshed evidence is retained at `/tmp/buysell-submit-readiness-nosign.log` and `/tmp/buysell-submit-readiness-nosign.xcarchive`.
- Binary-size check: archived app bundle stays under `20 MB`.
- App icon check: source App Store icon is a text-free camera-first 1024x1024 non-alpha PNG and the archive contains iPhone/iPad icon PNGs.
- Current-system design check: archived app omits `UIDesignRequiresCompatibility`.
- Native material polish: `NativeMaterialSurface.swift` centralizes SDK-safe glass-style surfaces with `ultraThinMaterial` and `regularMaterial` for the current Xcode 16.4/iOS 18.5 SDK while keeping compiler-gated iOS 26+ hooks for `glassEffect`, `GlassEffectContainer`, `GlassButtonStyle`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)` in the same wrapper. Shared primary, secondary, ghost, text-action, icon, Home settings gear, Auth and Settings system sheet presentation chrome, flow-sheet shell, sheet, bottom action, focused input, Settings row-icon, chip, toast, generated-listing, empty-history, History row, marketplace badge, and first-launch tutorial setup-control surfaces route through that wrapper so the control layer can move to real Liquid Glass from one source point once the release toolchain supports it. The Camera floating control cluster also routes through `nativeLiquidGlassControlGroup`, which becomes `GlassEffectContainer` on iOS 26+ while remaining a no-op on older SDK/runtime paths; the Camera surface now verifies tap focus, camera switching, and capture controls in the latest-design evidence. The wrapper responds to Reduce Transparency by raising tint opacity for icon circles, rounded panels, pills, bars, and sheets so glass-style controls become frostier and easier to read. `Info.plist` omits `UIDesignRequiresCompatibility` so iOS 26+ can use the current system presentation instead of design compatibility mode. Snap Result category and condition menu rows use SF Symbols with selected checkmarks. Final M10 readiness requires `Scripts/verify_m10_latest_design_sdk.sh` to pass with an Xcode/iPhoneOS SDK 27+ latest-design toolchain by default, and tutorial UI evidence confirms the full-screen swipe gesture still works with the material header/footer controls.
- System sheet chrome: `nativeSystemSheetPresentationChrome()` leaves Auth and Settings sheet backgrounds to the native Liquid Glass presentation on iOS 26+ builds; older SDK/runtime paths keep the existing `.regularMaterial` fallback. The latest-design verifier records `system sheet background: iOS 26+ native Liquid Glass, regularMaterial fallback`.
- Font setup polish: Space Grotesk and Inter static font files are registered in `Info.plist`, and design guardrails now prove every `BrandTextStyle` standard and Bold Text variant resolves to a real bundled font file while user-facing text avoids raw system font overrides and SF Symbol sizing routes through shared `BrandSymbolStyle` tokens.
- Home accessibility polish: the Home header separates the BuySell wordmark from the account/settings controls at accessibility Dynamic Type sizes so the first screen remains readable without crowding, while preserving the 44-point account and gear tap targets.
- Snap Result accessibility polish: the result header stacks the item photo above editable name and price controls at accessibility Dynamic Type sizes so critical review/edit controls stay readable before marketplace selection. Narrow-iPhone result actions keep quick retake/retry controls paired while rendering category and condition menu triggers as full-width material rows; wider iPhone and iPad result sheets retain the 2x2 grid without screenshot-visible truncation.
- Listing accessibility polish: the listing header separates the close button from the platform title stack at accessibility Dynamic Type sizes so the final copy sheet keeps its close affordance clear while marketplace names can wrap.
- Auth accessibility polish: the optional sign-in sheet keeps "Keep going without an account" in a sticky material bottom action at accessibility Dynamic Type sizes so guest selling stays one tap away.
- Camera accessibility polish: the camera shutter hint keeps a two-line-safe material pill and extra bottom clearance at accessibility Dynamic Type sizes so capture controls remain legible over the live preview.
- Snapshot verification polish: `Scripts/run_m10_ui_tests.sh` now supports `M10_UI_SNAPSHOT_ROOT=/tmp/buysell-m10-ui-worktree` for coordinated-folder Xcode stalls, and the no-sign, signed-archive, App Store export, and real-device preflights support `/tmp` snapshot worktrees through `M10_LOCAL_ARCHIVE_SNAPSHOT_ROOT`, `M10_SIGNED_ARCHIVE_SNAPSHOT_ROOT`, `M10_APP_STORE_EXPORT_SNAPSHOT_ROOT`, and `M10_REAL_DEVICE_SNAPSHOT_ROOT`; focused camera source evidence is retained at `/tmp/buysell-camera-bottom-controls-focused.xcresult`, camera overlay UI evidence at `/tmp/buysell-camera-bottom-controls-ui.xcresult`, snapshot-runner smoke evidence at `/tmp/buysell-m10-ui-snapshot-smoke/summary.log`, runner script guardrail evidence at `/tmp/buysell-ui-snapshot-runner-script-focused.xcresult`, and no-sign archive snapshot evidence at `/tmp/buysell-local-archive-snapshot-nosign.log` plus `/tmp/buysell-local-archive-snapshot-nosign.xcarchive`.
- Native haptic polish: Snap Result menu-open controls fire light haptics before category/condition choices appear, confirmed Home swipe-delete fires immediate warning feedback while suppressing duplicate store feedback, and the Settings delete-account row uses the shared haptic action-row pattern while still pushing the confirmation screen.
- Package checks: `PrivacyInfo.xcprivacy` is present. Privacy manifest content check passes for no tracking, app-functionality data use, and UserDefaults required-reason metadata. Camera permission metadata is present, and photo-library permission metadata is absent.
- Secret scan: the scanner self-test passes and no Gemini/OpenAI-style provider secret patterns are present in repo text files outside generated bundles.
- Workspace materialization check: `Scripts/check_workspace_materialization.sh` records whether Git metadata, app source, tests, Supabase sources, support-site sources, M10 docs, release verifiers, and retained App Store screenshots are locally readable instead of `dataless`. Current evidence is retained at `/tmp/buysell-submit-readiness-workspace-materialization.log`: `M10 workspace materialization passed`, Git can index the worktree, app/unit/UI/Supabase/support-site sources are locally readable, required iPhone 6.9-inch screenshots are `1320x2868`, required iPad 13-inch screenshots are `2064x2752`, and README/M10 acceptance/metadata/Today nomination docs are readable.
- Local source verification: `Scripts/typecheck_local_sources.sh` now passes from the materialized checkout for app, unit-test, and UI-test Swift sources using the iPhone Simulator 18.5 SDK; refreshed evidence is retained at `/tmp/buysell-local-source-typecheck.log`. A focused `xcodebuild test` source-smoke invocation against iPhone 16 Pro, iOS 18.6, was attempted at `/tmp/buysell-source-smoke.log` but did not progress past the initial Xcode invocation on this coordinated-folder checkout before being interrupted. The no-sign Release archive was then verified from the lean snapshot worktree, proving Xcode can compile and package the restored app sources when the coordinated-folder stall is avoided.
- Supabase source verification: `Scripts/check_supabase_schema.sh` passes with `history` and `apple_auth_tokens`, forced RLS, `(select auth.uid())` policy coverage, policy/index parity, history value/listing constraints, and unique Apple token identity storage; refreshed evidence is retained at `/tmp/buysell-submit-readiness-supabase-schema.log`. `Scripts/check_supabase_functions.sh` passes Deno checks for `analyze-image`, `generate-listing`, `store-apple-token`, and `delete-account`; refreshed evidence is retained at `/tmp/buysell-submit-readiness-supabase-functions.log`.
- Support-site source verification: `node --test tests/rendered-html.test.mjs` passes `3` rendered-page tests for the public support, privacy, accessibility, and terms pages. A fresh `npm run build` remained silent in `vinext build` and was interrupted, so refreshed support-site build evidence is still pending even though the retained `dist/server/index.js` rendered successfully under the test.
- DerivedData runtime smoke: the fully local compiled simulator app at `/Users/rhodes/Library/Developer/Xcode/DerivedData/BuySellAI-glfouuvczsstrjfmzpwwxnciozti/Build/Products/Debug-iphonesimulator/BuySellAI.app` installs and launches on the booted iPhone 16 Pro simulator (iOS 18.6), with a fresh Home screenshot retained at `/tmp/buysell-deriveddata-runtime-home.png` (`1206x2622`). A source-free `test-without-building` smoke slice from `BuySellAI_BuySellAI_iphonesimulator18.5-arm64.xctestrun` now passes `18` compiled unit tests across `MarketplaceEstimatorTests`, `ModelFormattingTests`, and `PrivacyManifestTests`, including marketplace fee/badge math, all `27` marketplace color-token routes, localization entries, marketplace catalog order/blurbs, decimal formatting, category/condition API stability, theme preference persistence, no tracking, app-functionality-only collected data, and UserDefaults required-reason metadata; evidence is retained at `/tmp/buysell-deriveddata-resource-smoke.xcresult` and `/tmp/buysell-deriveddata-resource-smoke.log`.
- Simulator performance evidence: launch, camera-ready, capture-to-result thumbnail, slow history load, and 500-row history scroll UI tests pass in the full suite; `Scripts/verify_m10_performance_evidence.sh` passed with 5 performance tests and a historical `3596KB / 20480KB` app-size result in `/tmp/buysell-submit-readiness-performance.log`. The refreshed no-sign archive verifier now records `4812KB / 20480KB`.
- App Store screenshot evidence: required iPhone 6.9-inch `1320 x 2868` PNGs are retained in `AppStoreAssets/Screenshots/iPhone-16-Pro-Max/`, required iPad 13-inch `2064 x 2752` PNGs are retained in `AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/`, both sets pass blank/dark-strip artifact and warm orange brand-signal checks, and both were captured by `BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured` in standalone result bundles `/tmp/buysell-m10-screenshots-iphone-16-pro-max.xcresult` and `/tmp/buysell-m10-screenshots-ipad-pro-13.xcresult`; the broader submit-readiness full-suite result bundle `/tmp/buysell-submit-readiness-full.xcresult` is also retained.
- Apple Today feature nomination evidence: `M10_TODAY_FEATURE_NOMINATION.md` records App Store Connect Featuring Nominations copy, Apple guidance/source links, lead-time expectations, editorial story, technology/accessibility/privacy angles, retained screenshot assets, and the text-free App Store icon; `Scripts/verify_m10_today_feature_nomination.sh` validates the package and writes `/tmp/buysell-submit-readiness-today-feature.log`, which the combined submit-readiness gate now requires.
- Latest local evidence: current full-suite result bundle `/tmp/buysell-submit-readiness-full.xcresult`, unit result bundle `/tmp/buysell-full-unit-tests-9.xcresult`, focused M10 guardrail result bundle `/tmp/buysell-submit-readiness-focused.xcresult`, required screenshot result bundles `/tmp/buysell-m10-screenshots-iphone-16-pro-max.xcresult` and `/tmp/buysell-m10-screenshots-ipad-pro-13.xcresult`, local app/unit/UI source typecheck log `/tmp/buysell-local-source-typecheck.log`, chunked UI summary `/tmp/buysell-m10-ui-tests/summary.log`, chunked UI evidence log `/tmp/buysell-submit-readiness-ui.log`, no-sign archive `/tmp/buysell-submit-readiness-nosign.xcarchive`, no-sign verifier log `/tmp/buysell-submit-readiness-nosign.log`, performance evidence log `/tmp/buysell-submit-readiness-performance.log`, latest-design SDK blocker log `/tmp/buysell-submit-readiness-latest-design-sdk.log`, signed-preflight blocker log `/tmp/buysell-submit-readiness-signed-preflight.log`, App Store export blocker log `/tmp/buysell-submit-readiness-export-preflight.log`, App Store validation blocker log `/tmp/buysell-submit-readiness-app-store-validation-preflight.log`, App Store metadata evidence log `/tmp/buysell-submit-readiness-app-store-metadata.log`, Supabase deploy-preflight blocker log `/tmp/buysell-submit-readiness-supabase-deploy.log`, Supabase schema static check log `/tmp/buysell-submit-readiness-supabase-schema.log`, backend blocker log `/tmp/buysell-submit-readiness-backend.log`, Supabase function type-check log `/tmp/buysell-submit-readiness-supabase-functions.log`, real-device blocker log `/tmp/buysell-submit-readiness-real-device-preflight.log`, real-device acceptance evidence blocker log `/tmp/buysell-submit-readiness-acceptance-evidence.log`, secret-scan log `/tmp/buysell-submit-readiness-secret-scan.log`, Instruments evidence blocker log `/tmp/buysell-submit-readiness-instruments.log`, and combined readiness blocker log `/tmp/buysell-submit-readiness-combined.log`.

## Commands

Run the full simulator suite:

```sh
xcodebuild test \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
```

Run the no-sign Release archive package check:

```sh
bash Scripts/verify_m10_local_archive.sh /tmp/buysell-submit-readiness-nosign.xcarchive
```

If Xcode stalls while loading the project from the full checkout, run the no-sign archive check from a lean iOS snapshot:

```sh
M10_LOCAL_ARCHIVE_SNAPSHOT_ROOT=/tmp/buysell-m10-archive-worktree \
bash Scripts/verify_m10_local_archive.sh /tmp/buysell-submit-readiness-nosign.xcarchive
```

Run the signed archive preflight after selecting a real Apple development team:

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

Run the App Store Connect export preflight after selecting a real Apple development team:

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

Run the App Store Connect validation preflight after exporting an IPA and configuring API-key credentials:

```sh
ASC_API_KEY_ID=<key-id> \
ASC_API_ISSUER_ID=<issuer-id> \
ASC_API_PRIVATE_KEYS_DIR=<directory-containing-AuthKey_key-id.p8> \
bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export \
  | tee /tmp/buysell-submit-readiness-app-store-validation-preflight.log
```

`M10_DEVELOPMENT_TEAM` lets the release preflights use a personal Apple Team ID without committing it to the Xcode project. Selecting the team in Xcode is also valid.

Until the Apple team, exported IPA, and App Store Connect API-key credentials are available, record the known blockers:

```sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_signed_archive.sh \
  | tee /tmp/buysell-submit-readiness-signed-preflight.log
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_app_store_export.sh \
  | tee /tmp/buysell-submit-readiness-export-preflight.log
ALLOW_MISSING_ASC=1 bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export \
  | tee /tmp/buysell-submit-readiness-app-store-validation-preflight.log
```

The default signed and App Store export preflights should pass without `ALLOW_MISSING_TEAM=1`, and the App Store validation preflight should pass without `ALLOW_MISSING_ASC=1`, before checking the signed archive gates below.

Run the App Store Connect metadata evidence verifier after product-page metadata, screenshots, public unauthenticated privacy/support/accessibility URLs, app privacy answers, Accessibility Nutrition Labels, age rating, DSA status, account-owner legal confirmation, and review notes are recorded:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

Passing logs include `file:`, `app name:`, `bundle id:`, `version:`, `privacy policy:`, `support:`, `accessibility url:`, `screenshots:`, `legal:`, `screenshot sets:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot quality:`, `screenshot result bundle:`, `screenshot capture test:`, `app privacy:`, `accessibility labels:`, and `accessibility evidence:` markers. The verifier also rejects assumption, pending, and confirm-before-submission wording in legal/account-owner fields, checks Accessibility Nutrition Label evidence for claimed iPhone/iPad accessibility features and common tasks, confirms the retained PNG screenshot files exist for the required iPhone 6.9-inch and iPad 13-inch display classes, match `1320x2868` and `2064x2752` dimensions, pass blank/dark-strip artifact checks, and confirms they came from retained xcresults where `testM10AppStoreScreenshotsCanBeCaptured()` passed. Allowed-pending output still emits the recorded evidence markers, but keeps the legal/account-owner blocker visible. Until those App Store Connect fields are complete, record the known blocker:

Screenshot metadata logs also include `screenshot brand signal: warm orange present`, proving the retained App Store screenshots carry the BuySell orange visual signal.

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

The App Store support/privacy/accessibility site source is in `AppStoreSite/`. Sites version 4 is saved from commit `1166ed88e30a28bdb159773010b77d09d555b3b4` and deployed at `https://buysell-ai-support.o5hinwavve.chatgpt.site`; site access is public, and unauthenticated support, privacy, accessibility, and terms requests return `200`. The metadata verifier checks that filled-in Support URL, Privacy Policy URL, and Accessibility URL values are public HTTPS pages reachable without authentication. App Store screenshot evidence is retained in `AppStoreAssets/Screenshots/iPhone-16-Pro-Max/` and `AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/`.

Run the Apple Today/App Store editorial nomination verifier after screenshots, metadata URLs, and the nomination package are refreshed:

```sh
bash Scripts/verify_m10_today_feature_nomination.sh M10_TODAY_FEATURE_NOMINATION.md \
  | tee /tmp/buysell-submit-readiness-today-feature.log
```

Passing logs include `M10 Today feature nomination package passed`, `file:`, `placement:`, `story:`, `lead time:`, `role:`, `assets:`, and `source:` markers. The verifier checks the App Store Connect Featuring Nominations path, Apple guidance links, the two-week minimum and three-month wider-consideration lead-time language, eligible App Store Connect roles, concrete Today/Apps tab pitch copy, native technology/accessibility/privacy story, retained App Store screenshots, public metadata URL references, and the text-free 1024x1024 icon. The package can make BuySell ready to nominate; Apple editorial placement is discretionary and cannot be verified locally.

Run the M10 backend smoke preflight after `Config.plist`, the migrated Supabase schema, the deployed Edge Functions, and a retained JPEG sample are available:

```sh
bash Scripts/setup_supabase_config.sh

M10_ANALYZE_IMAGE_JPEG=/path/to/common-item.jpg \
bash Scripts/preflight_m10_backend.sh BuySellAI/App/Config.plist
```

The app config helper writes only the public `SUPABASE_URL` and `SUPABASE_ANON_KEY` values to `BuySellAI/App/Config.plist`, prompts for them or reads environment variables with the same names for noninteractive setup, supports `SUPABASE_CONFIG_FROM_ENV=1` for fail-fast CI/release setup, rejects copied placeholders and provider-secret-shaped values, and keeps the anon key out of terminal output.

Type-check the local Supabase Edge Function sources before deploying them:

```sh
bash Scripts/check_supabase_functions.sh | tee /tmp/buysell-submit-readiness-supabase-functions.log
```

Run the local Supabase schema static check before deployment evidence:

```sh
bash Scripts/check_supabase_schema.sh | tee /tmp/buysell-submit-readiness-supabase-schema.log
```

Deployable Supabase Edge Function templates live in `supabase/functions/`, with schema in `supabase/migrations/`. Run `bash Scripts/setup_supabase_secrets.sh full` to set server-side `GEMINI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and Sign in with Apple private-key secrets through a 0600 temporary env file outside the repository, then run `supabase db push` and deploy `analyze-image`, `generate-listing`, `store-apple-token`, and `delete-account`; do not put provider, service-role, or Apple private-key secrets in the iOS app. For CI/release machines, set `SUPABASE_SECRETS_FROM_ENV` to `1` so the helper reads the same required values from secret environment variables and fails fast if any are missing. Use `bash Scripts/setup_supabase_secrets.sh gemini-only` only for an early guest analyze/listing smoke test; full App Store readiness still requires the service-role and Apple secrets. The `store-apple-token` function checks for duplicate Apple subjects, returns a 409 conflict when an Apple identity already belongs to another Supabase user, and stores Apple refresh-token material server-side so `delete-account` can attempt Sign in with Apple authorization revocation, delete the private token row, and still finish BuySell account deletion if Apple token cleanup is stale or temporarily unavailable. Missing or malformed Apple private-key secrets remain hard backend errors so release evidence cannot hide a revocation misconfiguration.

Before the remote deploy, run the guarded deployment preflight. It validates app config, the linked project, required server-side secret names, migrations, and Edge Function sources without printing secret values:

```sh
ALLOW_MISSING_SUPABASE_DEPLOY=1 bash Scripts/deploy_supabase_backend.sh preflight
```

After the app config, Supabase secrets, and `supabase link --project-ref <project-ref>` are complete, deploy with an explicit project confirmation:

```sh
CONFIRM_SUPABASE_DEPLOY=<project-ref> bash Scripts/deploy_supabase_backend.sh deploy | tee /tmp/buysell-submit-readiness-supabase-deploy.log
```

The local schema checker verifies the migrations without connecting to Supabase. Passing output includes `Supabase schema static check passed`, `tables: history apple_auth_tokens`, `rls: history apple_auth_tokens forced`, `policy: history authenticated select-auth-uid`, `indexes: history_user_created_at_idx apple_auth_tokens_apple_user_id_unique`, `grants: history authenticated service_role apple_auth_tokens service_role`, `constraints: history category condition marketplace listing apple-token-identity`, and `swift parity: category condition marketplace`; retain it as `/tmp/buysell-submit-readiness-supabase-schema.log` for the combined gate. The local Deno checker uses a local `deno` binary when available, or a temporary `npx --yes deno` fallback with `DENO_DIR` outside the repo. Passing output includes `Supabase function Deno check passed` and `functions: analyze-image generate-listing store-apple-token delete-account`; retain it as `/tmp/buysell-submit-readiness-supabase-functions.log` for the combined gate. Supabase deploy evidence must include `constraints: history category condition marketplace listing apple-token-identity`, proving the hardening migrations for native history value/listing constraints and unique Apple token identity storage are part of the release schema. The backend preflight reads only the public Supabase URL and anon key from `Config.plist`; it does not print the anon key or any AI provider secret. The app and preflight both reject copied `Config.plist.example` placeholders before making backend requests. It verifies `analyze-image` and `generate-listing` with live responses, including the plain-text `TITLE:` and `DESCRIPTION:` listing contract, then verifies `analyze-image` rejects missing image data, non-JPEG data URLs, and malformed base64 while `generate-listing` rejects unsupported platform, category, and condition values. It then probes `store-apple-token` and `delete-account` to confirm the protected account functions are deployed and reject anonymous requests. It also probes the migrated `history` and `apple_auth_tokens` PostgREST tables to confirm the schema is deployed and rejects anonymous reads. Passing logs include `config:`, `project:`, `schema: history apple_auth_tokens`, `functions: analyze-image generate-listing store-apple-token delete-account`, `protected functions: store-apple-token delete-account`, `protected tables: history apple_auth_tokens`, `analyze item:`, `analyze rejection contract: missing jpeg base64`, `listing contract:`, `listing rejection contract: platform category condition`, and `listing bytes:` markers.

Until the real Supabase config/functions and sample image are available, record the known blocker:

```sh
ALLOW_MISSING_BACKEND=1 bash Scripts/preflight_m10_backend.sh
```

Run the real-device preflight after connecting a trusted iPhone or iPad with Developer Mode enabled:

```sh
M10_DEVELOPMENT_TEAM=<team-id> bash Scripts/preflight_m10_real_device.sh \
  | tee /tmp/buysell-submit-readiness-real-device-preflight.log
```

If Xcode stalls while loading the project from the full checkout, run the real-device preflight from a lean iOS snapshot:

```sh
M10_REAL_DEVICE_SNAPSHOT_ROOT=/tmp/buysell-m10-real-device-worktree \
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_real_device.sh
```

To target a specific connected device:

```sh
M10_DEVELOPMENT_TEAM=<team-id> DEVICE_ID=<devicectl-identifier> bash Scripts/preflight_m10_real_device.sh \
  | tee /tmp/buysell-submit-readiness-real-device-preflight.log
```

The preflight ignores non-iOS `devicectl` entries. A supplied `DEVICE_ID` must match a connected iPhone or iPad.

Until a trusted physical device is connected, record the known blocker:

```sh
ALLOW_MISSING_DEVICE=1 bash Scripts/preflight_m10_real_device.sh \
  | tee /tmp/buysell-submit-readiness-real-device-preflight.log
```

Run the real-device manual acceptance evidence check after completing the device pass:

```sh
bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Until the physical-device QA pass is complete, record the known blocker:

```sh
ALLOW_PENDING_ACCEPTANCE=1 bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Run the secret-pattern scan:

```sh
bash Scripts/scan_m10_secrets.sh
```

The scan should print both `M10 secret scan self-test passed` and `M10 secret scan passed`.

Run the chunked M10 UI runner when the combined UI suite needs isolated, resumable simulator evidence:

```sh
bash Scripts/run_m10_ui_tests.sh
```

The runner executes each `BuySellAIUITests` test in its own non-parallel `xcodebuild` invocation, records per-test `.xcresult` and `.log` artifacts, and writes the rollup to `/tmp/buysell-m10-ui-tests/summary.log`. It retries simulator launch/preflight/install-worker infrastructure failures once by default (`M10_UI_MAX_ATTEMPTS=2`) while still failing immediately for app assertions; use `M10_UI_CONTINUE_ON_FAILURE=1 bash Scripts/run_m10_ui_tests.sh` to keep collecting failures after the first failing test. The performance and submit-readiness gates still require the retained full-suite result bundle.

If Xcode project loading stalls while the checkout sits in a coordinated folder such as `Documents`, run the chunked evidence from a lean iOS snapshot:

```sh
M10_UI_SNAPSHOT_ROOT=/tmp/buysell-m10-ui-worktree bash Scripts/run_m10_ui_tests.sh
```

Snapshot mode copies the app, Xcode project, tests, scripts, Supabase sources, screenshot assets, and M10 docs into `/tmp`, skips support-site build artifacts such as `AppStoreSite/node_modules`, and still writes the normal per-test result bundles and rollup under `M10_UI_RESULT_ROOT`.

Run the chunked UI evidence verifier after the runner finishes:

```sh
bash Scripts/verify_m10_ui_evidence.sh \
  /tmp/buysell-m10-ui-tests \
  | tee /tmp/buysell-submit-readiness-ui.log
```

The verifier derives the current UI-test list from `BuySellAIUITests.swift`, checks the runner summary, verifies every per-test `.xcresult` reports one passing test, and retains `M10 UI evidence passed`, `summary:`, `result root:`, `tests:`, and per-test `test:` markers for the combined gate.

Run the M10 performance evidence verifier after the full simulator suite and no-sign archive verifier finish:

```sh
bash Scripts/verify_m10_performance_evidence.sh \
  /tmp/buysell-submit-readiness-full.xcresult \
  /tmp/buysell-submit-readiness-nosign.log
```

The performance evidence verifier checks the full-suite result, named simulator performance UI tests, the archived app-size budget, and carries forward the no-sign archive `bundle id:` and `release build:` markers. It does not replace the final physical-device timing checks in the real-device acceptance table.

Run the M10 Instruments evidence verifier after profiling a signed Release build on a trusted physical device with Time Profiler and Allocations:

```sh
bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

Until the signed physical-device Instruments pass is complete, record the known blocker:

```sh
ALLOW_PENDING_INSTRUMENTS=1 bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

The Instruments evidence verifier checks the final hardware timing, scroll, memory, and trace-retention evidence in `M10_INSTRUMENTS.md`.

Run the latest-design SDK verifier after switching to the release Xcode/iPhoneOS SDK that includes Liquid Glass:

```sh
bash Scripts/verify_m10_latest_design_sdk.sh
```

This verifier requires Xcode and the iPhoneOS SDK major version to be `27` or newer by default and checks that `NativeMaterialSurface.swift` contains compiler-gated iOS 26+ Liquid Glass hooks for `glassEffect`, `GlassEffectContainer`, `GlassButtonStyle`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)` while `Info.plist` omits `UIDesignRequiresCompatibility`. It also verifies primary CTAs use iOS 26+ prominent glass with an orange tint while keeping the orange capsule as the older-SDK fallback, standard buttons use iOS 26+ standard glass with material fallbacks for remaining custom controls, Home uses a native inset grouped task list with toolbar account/settings actions, Camera controls preserve compiler-gated `GlassEffectContainer` support on iOS 26+, Auth uses native inset grouped sign-in rows with system bottom bars, Tutorial uses a native inset grouped guide with a system bottom bar, and Snap Result category/condition menus use SF Symbol rows with selected checkmarks. Until the current machine has that toolchain, retain the known SDK blocker:

```sh
ALLOW_MISSING_LIQUID_GLASS_SDK=1 bash Scripts/verify_m10_latest_design_sdk.sh > /tmp/buysell-submit-readiness-latest-design-sdk.log
```

Run the workspace materialization preflight before the combined M10 gate, especially when the checkout is in a file-provider-backed `Documents` folder:

```sh
bash Scripts/check_workspace_materialization.sh \
  | tee /tmp/buysell-submit-readiness-workspace-materialization.log
```

If files are still cloud-only/dataless on another checkout, keep the blocker visible while the provider downloads them:

```sh
ALLOW_DATALLESS_WORKSPACE=1 bash Scripts/check_workspace_materialization.sh \
  | tee /tmp/buysell-submit-readiness-workspace-materialization.log
```

Passing output includes `M10 workspace materialization passed`, `git:`, `sources:`, `screenshots:`, and `docs:` markers. The combined M10 gate should not be treated as authoritative until this passes without `ALLOW_DATALLESS_WORKSPACE=1`. Current evidence at `/tmp/buysell-submit-readiness-workspace-materialization.log` passes without the pending override.

Run the combined M10 submit-readiness gate after producing every evidence artifact above:

```sh
bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

The combined gate checks that pass logs retain their concrete artifact markers: no-sign `archive:`, `bundle id:`, `release build:`, `app icon:`, `system design:`, and `app size:`, latest design `M10 latest design SDK passed`, `xcode:`, `iphoneos sdk:`, `liquid glass sdk:`, `source:`, `source liquid glass:`, `primary button glass:`, `standard button glass:`, `home setup:`, `camera setup:`, `auth setup:`, `tutorial setup:`, `menu item icons:`, and `system sheet background:`, local source typecheck `BuySellAI local source typecheck passed`, `target:`, `sdk:`, and `sources:`, signed `archive:`, `bundle id:`, `sign in with apple:`, and `release build:`, App Store export `archive:`, `export:`, `ipa:`, `bundle id:`, `sign in with apple:`, and `release build:`, App Store validation `ipa:`, `bundle id:`, `sign in with apple:`, and `release build:`, App Store metadata `app name:`, `bundle id:`, `privacy policy:`, `support:`, `accessibility url:`, `screenshots:`, `legal:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot quality:`, `screenshot result bundle:`, `screenshot capture test:`, `app privacy:`, `accessibility labels:`, and `accessibility evidence:`, Today feature nomination `M10 Today feature nomination package passed`, `file:`, `placement:`, `story:`, `lead time:`, `role:`, `assets:`, and `source:`, Supabase deploy `M10 Supabase deploy passed`, `config:`, `project:`, `project ref:`, `schema:`, `constraints:`, `functions:`, and `secrets:`, Supabase schema static check `Supabase schema static check passed`, `tables:`, `rls:`, `policy:`, `indexes:`, `grants:`, `constraints:`, and `swift parity:`, Supabase function type-check `Supabase function Deno check passed` and `functions:`, backend `config:`, `project:`, `schema:`, `functions:`, `protected functions:`, `protected tables:`, `analyze item:`, `analyze rejection contract:`, `listing contract:`, `listing rejection contract:`, and `listing bytes:`, real-device `device:`, `device name:`, `device id:`, `app:`, `bundle id:`, `sign in with apple:`, and `release build:`, secret scan `M10 secret scan self-test passed` and `M10 secret scan passed`, chunked UI `M10 UI evidence passed`, `summary:`, `result root:`, `tests:`, and `test:`, performance `full suite:`, `archive log:`, `bundle id:`, `release build:`, `performance tests:`, `performance test:`, and `app size:`, and Instruments `file:`. It also confirms the local simulator result bundles, local source typecheck log, no-sign archive, no-sign verifier log, latest-design SDK evidence log, Today feature nomination log, Supabase schema static check log, Supabase function type-check log, secret-scan log, chunked UI evidence log, and performance evidence log are fresh for the current HEAD commit; passing signed/App Store/backend/Supabase deploy/real-device/Instruments artifacts must be fresh too. It confirms the App Store validation log references the same `ipa:` path produced by the export preflight, the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `bundle id:` marker, the signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `sign in with apple:` entitlement marker, the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs record the same `release build:` value, the Supabase deploy and backend preflight logs retain the same `project:` marker, the chunked UI evidence log retains the runner summary and App Store screenshot UI test markers, the performance evidence log retains the same no-sign archive `bundle id:` and `release build:` values plus every required simulator budget test name, the acceptance `Signed archive` metadata references the signed-preflight `archive:` path, the acceptance `Signed archive validation` metadata mentions Xcode Organizer validation proof and references the signed-preflight `archive:` path, the acceptance `App Store validation` metadata references the validated `ipa:` path, the acceptance and Instruments `Release build` metadata match the signed-preflight `release build:` value, the acceptance and Instruments `Device model` metadata reference the real-device preflight `device name:` value, the Instruments `Signed archive` metadata references the same signed-preflight `archive:` path, and the acceptance and Instruments `iOS version` and `Release build` metadata match for the same physical-device pass. If your retained artifacts use non-default paths, set `M10_SOURCE_TYPECHECK_LOG`, `M10_NOSIGN_ARCHIVE`, `M10_LATEST_DESIGN_SDK_LOG`, `M10_SIGNED_ARCHIVE`, `M10_APP_STORE_ARCHIVE`, `M10_APP_STORE_EXPORT`, `M10_APP_STORE_METADATA`, `M10_APP_STORE_METADATA_LOG`, `M10_TODAY_FEATURE_NOMINATION`, `M10_TODAY_FEATURE_LOG`, `M10_BACKEND_LOG`, `M10_SUPABASE_DEPLOY_LOG`, `M10_SUPABASE_SCHEMA_CHECK_LOG`, `M10_SUPABASE_FUNCTION_CHECK_LOG`, `M10_UI_EVIDENCE_LOG`, and `M10_INSTRUMENTS_EVIDENCE` before running this gate.

The combined gate also requires the App Store metadata log's `screenshot brand signal: warm orange present` marker and the Today feature nomination log's Apple source, placement, lead-time, role, story, and asset markers. It requires a clean git worktree, so every release source, screenshot, script, and evidence-document change must be committed or intentionally stashed before final submit-readiness can pass.

The combined gate checks a retained unit test suite result bundle; the current default evidence is `/tmp/buysell-full-unit-tests-9.xcresult` with `389` passing unit-target tests. If a newer refreshed unit bundle is collected, set `M10_UNIT_XCRESULT` and `M10_MIN_UNIT_TESTS` to that concrete artifact and count before running the gate.

Until the latest-design SDK, signed archive, App Store metadata/submission, backend, real-device, and manual evidence gates are complete, record the known blockers:

```sh
ALLOW_PENDING_M10=1 bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

## Submit-Ready Gates

- [ ] Configure a real Apple development team for the app target.
- [ ] Produce a signed Release archive with automatic signing enabled.
- [ ] Export an App Store Connect IPA with automatic signing enabled.
- [ ] Validate the signed archive in Xcode Organizer.
- [ ] Validate the exported IPA with App Store Connect API-key credentials.
- [x] Materialize the file-provider-backed workspace so Git, source reads, screenshot inspection, and release verifiers are locally trustworthy.
- [ ] Complete App Store Connect metadata, screenshots, public privacy/support/accessibility URLs, app privacy answers, Accessibility Nutrition Labels, age rating, DSA status, and legal owner fields.
- [x] Run the Apple Today feature nomination verifier and retain `/tmp/buysell-submit-readiness-today-feature.log`.
- [ ] Run the M10 backend smoke preflight against the production Supabase project.
- [ ] Confirm Sign in with Apple entitlement is present in the signed archive.
- [x] Confirm App Store privacy manifest validation passes.
- [ ] Run the M10 latest-design SDK verifier with Xcode/iPhoneOS SDK 27+ by default.
- [ ] Run the real-device preflight on a trusted physical iPhone or iPad.
- [ ] Record a passing 15-item real-device acceptance evidence table.
- [x] Run the M10 performance evidence verifier.
- [ ] Run the M10 Instruments evidence verifier.
- [ ] Run the combined M10 submit-readiness gate without `ALLOW_PENDING_M10=1`.

## Real-Device Acceptance

Record the metadata before checking the items. Run `Scripts/preflight_m10_real_device.sh` first so the app has a Release build path for the same trusted device, then update every Result to `Pass` and replace every `TBD` evidence note. Metadata is validated too: `Date` must use `YYYY-MM-DD`, `Device model` must mention iPhone or iPad and include the real-device preflight `device name:` value, `iOS version` and `Release build` must include numeric values, `Release build` must match the signed-preflight `release build:` marker before final submit-readiness, `Signed archive` must mention an archive and include the signed-preflight `archive:` path, `Signed archive validation` must mention Xcode Organizer validation proof and include the signed-preflight `archive:` path, and `App Store validation` must mention validation, validated, altool, App Store, or IPA proof and include the validated `ipa:` path. For A01-A03, include the measured duration in `ms` or seconds in the Evidence cell so the verifier can enforce the launch, camera-ready, and capture-to-result budgets.

Every Evidence cell must cite the observed proof, not only say "passed". The verifier checks for these proof terms: A01 `home`, `no flicker`; A02 `camera`, `preview`; A03 `result sheet`, `thumbnail`; A04 `item`, `price`; A05 `platform`, `payout`, `best`, `lowest`, `27`, `ebay`, `craigslist`, `facebook`, `poshmark`, `mercari`, `offerup`, `depop`, `whatnot`, `grailed`, `reverb`, `etsy`, `stockx`, `goat`, `kidizen`, `vinted`, `vestiaire`, `the realreal`, `swappa`, `tradesy`, `chairish`, `bonanza`, `curtsy`, `nextdoor`, `amazon`, `shopify`, `ruby lane`, `tcgplayer`; A06 `clipboard`, `listing text`, `no leading whitespace`, `no preamble`; A07 `home`, `thumbnail`; A08 `swipe`, `haptic`; A09 `relaunch`, `guest`, `swiftdata`, `signed`, `server`; A10 `settings`, `reduce motion`, `animation`, `app-wide`; A11 `dark`, `contrast`; A12 `landscape`, `portrait`; A13 `voiceover`, `home`, `camera`, `result`, `picker`, `listing`, `copy`; A14 `airplane`, `offline`, `you're offline. reconnect and try again.`, `retry`; A15 `sign in with apple`, `migration`, `once`, `duplicate`.

| Field | Value |
| --- | --- |
| Device model | TBD |
| iOS version | TBD |
| Backend project | TBD |
| Tester | TBD |
| Date | TBD |
| Release build | TBD |
| Signed archive | TBD |
| Signed archive validation | TBD |
| App Store validation | TBD |

| ID | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| A01 | Cold launch reaches Home in under 1 second with no flicker. | Pending | TBD |
| A02 | Tapping `Snap to sell` opens a live camera preview within 400 ms. | Pending | TBD |
| A03 | Shutter capture presents the result sheet within 300 ms and includes a valid thumbnail. | Pending | TBD |
| A04 | Analyze returns a name and price for a common household item. | Pending | TBD |
| A05 | Marketplace picker shows the same platforms as §8.5 with plausible payouts and correct Best/Lowest badges. | Pending | TBD |
| A06 | Copy places only listing text on the clipboard, with no leading whitespace or generated preamble. | Pending | TBD |
| A07 | Recent listing appears on Home immediately after copy and includes a working thumbnail. | Pending | TBD |
| A08 | Swipe-to-delete removes the listing and fires warning haptic feedback. | Pending | TBD |
| A09 | Kill and re-open the app -> history persists (guest via SwiftData; signed-in via server). | Pending | TBD |
| A10 | Reduce Motion in Settings reduces app-wide animation. | Pending | TBD |
| A11 | Dark mode keeps every screen readable with acceptable contrast. | Pending | TBD |
| A12 | iPhone landscape rotation keeps the app portrait and stable. | Pending | TBD |
| A13 | VoiceOver can complete Home -> Camera -> Result -> Picker -> Listing -> Copy without ambiguity. | Pending | TBD |
| A14 | Airplane mode allows capture, then analyze fails with `You're offline. Reconnect and try again.` plus retry. | Pending | TBD |
| A15 | Sign in with Apple migrates guest history once without duplicates. | Pending | TBD |

## Result Log

Use one row per real-device pass.

Before the combined submit-readiness gate can pass, replace the placeholder row with at least one complete row from the final signed physical-device QA pass. Every field must be concrete, `Result` must be `Pass`, the row must match the recorded Date, Tester, Device model, iOS version, and Backend project metadata, and `Notes` must mention the signed archive, Xcode Organizer signed archive validation, App Store validation, real-device acceptance, and Instruments evidence used for that pass.

| Date | Tester | Device | iOS | Backend | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | TBD | TBD | Pending | Signed archive and real-device QA not yet complete. |
