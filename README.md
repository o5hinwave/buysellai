# BuySell AI iOS

Native SwiftUI rebuild of BuySell AI for iOS 17+.

## Open

Open `BuySellAI.xcodeproj` in Xcode 16.4 or newer.

To connect the real Supabase backend, copy:

```sh
cp BuySellAI/App/Config.plist.example BuySellAI/App/Config.plist
```

Then fill in:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

`Config.plist` is git-ignored.

Keep AI provider secrets, including Gemini keys, out of the iOS bundle. Add them to the Supabase Edge Function environment instead, using the variable name expected by the deployed functions (commonly `GEMINI_API_KEY`), then let the app call the existing `analyze-image` and `generate-listing` functions through Supabase. Rotate any provider key that was pasted into chat, logs, or git before using it for production. The bundled config parser accepts only `SUPABASE_URL` and `SUPABASE_ANON_KEY` and rejects provider-secret-shaped values.

Safe Gemini setup for the existing Edge Functions:

```sh
read -rsp "Gemini API key: " GEMINI_API_KEY; printf '\n'
printf 'GEMINI_API_KEY=%s\n' "$GEMINI_API_KEY" > .env
supabase secrets set --env-file .env
rm .env
unset GEMINI_API_KEY
```

`.env` is git-ignored. Do not paste provider secrets into `Config.plist`, Xcode build settings, source files, test fixtures, or shell commands that would remain in history.

Signed-in history sync expects a PostgREST `history` table protected by RLS:

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
  listing_text text not null
);

alter table public.history enable row level security;

create policy "Users can manage their own history"
on public.history
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());
```

Account deletion calls a Supabase Edge Function:

```txt
POST /functions/v1/delete-account
Authorization: Bearer <supabaseAccessToken>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{}
```

The function should verify `auth.uid()`, delete the user-owned data covered by RLS, then delete the auth user server-side with privileged credentials.

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
bash Scripts/verify_m10_local_archive.sh /tmp/BuySellAI-nosign.xcarchive
```

Signed archive preflight:

```sh
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_signed_archive.sh /tmp/BuySellAI-signed.xcarchive
```

App Store Connect export preflight:

```sh
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_app_store_export.sh /tmp/BuySellAI-appstore.xcarchive /tmp/BuySellAI-appstore-export
```

App Store Connect validation preflight after export and API-key setup:

```sh
ASC_API_KEY_ID=<key-id> \
ASC_API_ISSUER_ID=<issuer-id> \
ASC_API_PRIVATE_KEYS_DIR=<directory-containing-AuthKey_key-id.p8> \
bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export
```

App Store Connect metadata evidence after product-page metadata, screenshots, privacy/support URLs, app privacy answers, age rating, DSA status, and review notes are recorded:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

The metadata verifier checks concrete App Store Connect fields, unauthenticated public HTTPS privacy/support URLs, screenshot evidence, review notes, the 100-byte keyword limit, and privacy answers matching `PrivacyInfo.xcprivacy`. It also verifies the retained PNG screenshot files exist, match the expected `1206x2622` iPhone 16 Pro dimensions, and came from a retained xcresult where `testM10AppStoreScreenshotsCanBeCaptured()` passed. Passing logs include `file:`, `app name:`, `bundle id:`, `version:`, `privacy policy:`, `support:`, `screenshots:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot result bundle:`, `screenshot capture test:`, and `app privacy:` markers. Retain the passing output as `/tmp/buysell-submit-readiness-app-store-metadata.log` for the combined gate. Until those fields are complete, record the known blocker:

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

The App Store support/privacy site source lives in `AppStoreSite/`. Sites version 3 was saved from commit `2cbaf9521ecb2848d4ef9c321670dc8968055f34` and deployed at `https://buysell-ai-support.o5hinwavve.chatgpt.site`; site access was changed to public on 2026-07-16, and unauthenticated support, privacy, and terms requests return `200`. The iOS Settings legal links use the same Sites host, so the App Store Support URL and Privacy Policy URL fields point at the public `/support` and `/privacy` pages. App Store screenshot evidence is retained in `AppStoreAssets/Screenshots/iPhone-16-Pro/` from a passing iPhone 16 Pro simulator capture. Metadata assumptions recorded for App Store Connect are age rating `4+`, DSA status `Not a trader`, and copyright `2026 Rhodes`; the account owner should confirm those exact legal answers before final submission.

Backend smoke preflight after `Config.plist`, the deployed Edge Functions, and a retained JPEG sample are available:

```sh
M10_ANALYZE_IMAGE_JPEG=/path/to/common-item.jpg \
bash Scripts/preflight_m10_backend.sh BuySellAI/App/Config.plist
```

The backend preflight reads only the public Supabase URL and anon key from `Config.plist`; it does not print the anon key or any AI provider secret. The app and preflight both reject copied `Config.plist.example` placeholders before making backend requests. Passing logs include `config:`, `project:`, `functions: analyze-image generate-listing`, `analyze item:`, and `listing bytes:` markers. Retain the passing output as `/tmp/buysell-submit-readiness-backend.log` for the combined gate. Until the real Supabase config and sample image are available, record the known blocker:

```sh
ALLOW_MISSING_BACKEND=1 bash Scripts/preflight_m10_backend.sh
```

`M10_DEVELOPMENT_TEAM` lets local release preflights use a personal Apple Team ID without committing it to the Xcode project. You can also select the team in Xcode instead.

Until the Apple team, exported IPA, and App Store Connect API-key credentials are available, record the known blockers:

```sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_signed_archive.sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_app_store_export.sh
ALLOW_MISSING_ASC=1 bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export
```

Real-device preflight after connecting a trusted iPhone or iPad with Developer Mode enabled:

```sh
M10_DEVELOPMENT_TEAM=<team-id> bash Scripts/preflight_m10_real_device.sh
```

To target a specific connected device:

```sh
M10_DEVELOPMENT_TEAM=<team-id> DEVICE_ID=<devicectl-identifier> bash Scripts/preflight_m10_real_device.sh
```

The preflight ignores non-iOS `devicectl` entries. A supplied `DEVICE_ID` must match a connected iPhone or iPad. Passing logs include `device:`, `device name:`, `device id:`, `app:`, `bundle id:`, `sign in with apple:`, and `release build:` markers so final acceptance and Instruments metadata can point back to the same trusted device and Release build.

Until a trusted physical device is connected, record the known hardware blocker:

```sh
ALLOW_MISSING_DEVICE=1 bash Scripts/preflight_m10_real_device.sh
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

Combined M10 submit-readiness evidence gate:

```sh
bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

The performance verifier carries forward the no-sign archive log's `bundle id:`, `release build:`, and `app size:` markers, and records each required simulator budget test as a `performance test:` marker. The combined gate expects retained artifact markers in the preflight logs and requires the local simulator result bundles, no-sign archive, no-sign verifier log, secret-scan log, and performance evidence log to be fresh for the current HEAD commit; passing signed/App Store/backend/real-device/Instruments artifacts must be fresh too. It confirms the no-sign archive log retains the `app icon:` marker, confirms the App Store validation log references the same `ipa:` path produced by the export preflight, confirms the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `bundle id:` marker, confirms the signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `sign in with apple:` entitlement marker, confirms the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs record the same `release build:` value, confirms the App Store metadata log retains `app name:`, `bundle id:`, `privacy policy:`, `support:`, `screenshots:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot result bundle:`, `screenshot capture test:`, and `app privacy:` markers, confirms the secret-scan log retained the scanner self-test and repo-clean markers, confirms the performance evidence log retains the same no-sign archive `bundle id:` and `release build:` values plus every required simulator budget test name, and confirms the backend preflight log proves the live `analyze-image` and `generate-listing` Edge Functions without exposing secrets. The combined gate also confirms the manual acceptance and Instruments metadata reference the real-device preflight `device name:` value and signed-preflight `archive:` path while acceptance also references signed archive validation proof from Xcode Organizer and the validated `ipa:` path. The manual acceptance and Instruments evidence must also record matching iOS version and release build metadata for the same physical-device pass, and that release build must match the signed-preflight `release build:` marker. If you use non-default artifact paths, set the matching environment variables before running it: `M10_NOSIGN_ARCHIVE`, `M10_SIGNED_ARCHIVE`, `M10_APP_STORE_ARCHIVE`, `M10_APP_STORE_EXPORT`, `M10_APP_STORE_METADATA`, `M10_APP_STORE_METADATA_LOG`, `M10_BACKEND_LOG`, and `M10_INSTRUMENTS_EVIDENCE`.

Until every signed archive, App Store metadata/submission, backend, real-device, and manual evidence item is complete, record the known readiness blocker:

```sh
ALLOW_PENDING_M10=1 bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

The no-sign archive verifier validates the Release iPhoneOS build, 1024x1024 non-alpha source App Store icon plus archived iPhone/iPad icon PNGs, privacy manifest content, privacy/package metadata, camera-only permissions, and the `<20 MB` app bundle target. A fully signed App Store archive, App Store Connect IPA export, and App Store Connect validation still require selecting a real Apple development team in Xcode and providing App Store Connect API-key credentials.

Track final signed-archive and real-device acceptance in `M10_ACCEPTANCE.md`. The final `Result Log` must include a complete `Pass` row with concrete Date, Tester, Device, iOS, Backend, Result, and Notes fields before the combined submit-readiness gate can pass. At least one Pass row must match the recorded Date, Tester, Device model, iOS version, and Backend project metadata. The Notes field must mention the signed archive, Xcode Organizer signed archive validation, App Store validation, real-device acceptance, and Instruments evidence used for the pass.

## Assumptions

- Supabase project values were not present in the blank repository. The API client is implemented against the requested `analyze-image` and `generate-listing` contracts, and the app shows friendly configuration errors until `Config.plist` is supplied.
- Supabase Auth must have Apple enabled for full server-backed Sign in with Apple. Without backend config, Apple sign-in still stores the Apple user identifier locally and leaves guest history local.
- Space Grotesk and Inter static font faces are bundled from Google Fonts under the Open Font License and registered through `UIAppFonts`; Inter Bold is included so Bold Text can switch body copy to a true bold face.
- Sign in with Apple has a native nonce-based coordinator, Supabase token exchange, Keychain token persistence, and guest-to-account history migration. Delete account is wired to a `delete-account` Edge Function and still requires that backend function to be deployed.
- `Config.plist.example` is kept in the repo for setup instructions but excluded from the app target so placeholder backend values are not shipped in the bundle.
- Real-device camera latency, Accessibility Inspector contrast checks, signed App Store archive validation, the signed-archive and App Store export preflights without `ALLOW_MISSING_TEAM=1`, the App Store validation preflight without `ALLOW_MISSING_ASC=1`, App Store Connect account-owner legal field confirmation, the backend smoke preflight without `ALLOW_MISSING_BACKEND=1`, the real-device preflight without `ALLOW_MISSING_DEVICE=1`, the real-device acceptance evidence check without `ALLOW_PENDING_ACCEPTANCE=1`, the Instruments evidence check without `ALLOW_PENDING_INSTRUMENTS=1`, and the combined submit-readiness gate without `ALLOW_PENDING_M10=1` still need physical-device/account QA. The performance evidence verifier covers only repeatable simulator and package-size evidence; final Time Profiler and Allocations evidence is tracked separately in `M10_INSTRUMENTS.md`.

## Milestone Status

- M1 Skeleton: built. Xcode project, design tokens, typography, launch screen, Home shell.
- M2 Camera: built. AVCapture preview, permission handling, torch, capture, downscale.
- M3 Analyze: built. API client contract, loading/success/error result sheet, inline editing.
- M4 Marketplace picker: built. Full marketplace list, metadata, fee table, estimator, sticky summary.
- M5 Listing: built. API contract, listing sheet, copy, haptics, toast.
- M6 History: built. SwiftData guest persistence, Home list, delete, reopen listing.
- M7 Auth: built. Native optional auth UI, Apple sign-in token exchange, Keychain persistence, signed-in remote history sync, and guest-to-account migration.
- M8 Tutorial: built. Five-slide first-launch walkthrough with swipe and reduce-motion support.
- M9 Settings + polish: built. Theme, app-wide reduce motion, history clearing, once-per-version review prompt gating, about links, account actions.
- M10 QA: partial. 325 unit/UI tests pass in simulator, including localized Snap Result price-editing coverage, repeatable hidden-file secret scan guardrails, repeatable signed-archive preflight guardrails, repeatable App Store export preflight guardrails, repeatable App Store validation preflight guardrails, repeatable App Store metadata guardrails, repeatable backend smoke preflight guardrails, repeatable real-device preflight guardrails, repeatable real-device acceptance evidence guardrails, repeatable combined submit-readiness guardrails, repeatable performance evidence guardrails, repeatable Instruments evidence guardrails, repeatable no-sign archive/package-size verifier coverage, friendly auth error presentation for Sign in with Apple cancellation/failure and auth transport failures, friendly analyze/listing error presentation for transport and unknown failures, numeric light/dark contrast-token coverage, readable orange foreground-token guardrails, offline analyze retry/toast, listing-generation offline toast/regenerate coverage, listing error-state copy-action guardrails, selectable listing text panel and sticky listing action guardrails, analyze-response follow-up/tax field ignore coverage, anonymous analyze/listing request-shape coverage, camera shutter-to-offline-analyze thumbnail/error path, simulator shutter-to-result thumbnail budget guard, camera permission-denied settings fallback, camera ready-overlay VoiceOver labels, camera-only no photo-picker guard, camera capture orientation rotation mapping, camera back-only selection fallback guardrails, camera viewfinder 24-point inset and 3:4 aspect guardrails, camera torch/flash availability guardrails, camera configuration lock/unlock guardrails, camera configuration scoped-commit guardrails, camera preview freeze-before-downscale guardrails, dismissal-safe capture-to-result state transition with thumbnail data, API/auth/history/account timeout, non-2xx, rate-limit, retry, DNS/host/connect offline mapping, and delete-account offline mapping, generate-listing signed request and price payload coverage, generate-listing route-level timeout/offline/rate-limit/non-2xx/retry/malformed-response/blank-response mapping, Apple auth token-exchange Supabase identity separation, refresh-token preservation, refresh-session non-2xx/timeout/offline/rate-limit/retry/malformed-response mapping, auth network-lost retry coverage across Apple, email, and refresh routes, Apple auth non-2xx mapping, signed-in Home refresh replacing history from remote rows, stale remote refresh protection after a newly saved listing, stale sign-in migration/fetch protection after sign-out or a newly saved listing, stale remote save/delete/clear completion guards after sign-out or newer history changes, delete-account success/failure state cleanup coverage, delete-account network-lost retry coverage, remote history fetch/upsert/delete/clear route-level error/retry coverage, remote history both 5xx and network-lost retry coverage, remote history duplicate-row suppression, remote history display-formatted category/condition/marketplace compatibility, remote history optimistic rollback and mapped toast coverage, decoded-response malformed JSON mapping, optional auth dismissal with guest snap continuity, exact clipboard-copy, settings preference persistence, settings preference-control VoiceOver labels, settings grouped-list styling, settings section-limit and gated danger-zone guardrails, explicit settings close control, settings About in-app Safari guardrails, dark-mode Home-to-Listing flow navigation, app-level Reduce Motion propagation through animated surfaces, screen-transition timing, root sheet presentation guardrails, 300 ms splash timing guardrails, skeleton shimmer reduce-motion guardrails, slow history refresh not blocking Home launch, 500-row Home history UI scroll guard, simulator Home launch budget guard, simulator camera-ready overlay budget guard, accessibility3 Home primary-action reachability, Home display headline multiline scaling guard, Home header sign-in tap-target minimum, Home gear 40-point visual tap-target guardrails, Home primary-glow elevation-token scoping, Home re-opening the How it works tutorial, settings re-opening the How it works tutorial, tutorial custom illustration guardrails, tutorial step-value accessibility guardrails, tutorial next/get-started walkthrough, tutorial swipe navigation, tutorial keyboard navigation guardrails, auth email sign-in navigation-push guardrails, auth provider button-height guardrails, auth period-free BuySell AI wordmark guardrails, settings clear-history confirmation and removal, delete-account typed confirmation gating, delete-account VoiceOver label coverage, source-wide Button accessibility-label guardrails, marketplace catalog parity, marketplace estimate Codable round-trip and Decimal-preserving payout coverage, marketplace localization parity, marketplace brand-tint design-token guardrails, source localization-key coverage, SwiftUI localization-wrapper guardrails, model display-copy localization coverage, Decimal currency-formatting precision guardrails, marketplace VoiceOver payout labels, presented-sheet VoiceOver sort-priority coverage, VoiceOver critical-path UI label coverage from Home through Copy, Snap Result chip VoiceOver labels and action hints, Snap Result still-working alert announcement guardrails, Snap Result error action ordering, tokenized pure black/white SwiftUI color guardrails, chip-button tap-target minimums, ghost-button pill shape guardrails, marketplace summary direct-listing navigation, Snap Result edit committing, Snap Result retry loading hint scoping, Snap Result stale retry protection, cancellation-friendly analyze/listing copy, listing regeneration attempt scoping, listing retake preserving the selected marketplace, recent listing reopen skipping the marketplace picker, flow transition stale-presentation cancellation, image downscale pixel sizing, local save thumbnail persistence, exact decimal local price persistence, guest history relaunch persistence with newest-first ordering, recent listing working-thumbnail status in the copy/relaunch UI flow, Apple user ID Keychain persistence, AuthSession identity coverage, signed-in relaunch remote-history hydration coverage, analysis success/failure haptic routing, marketplace-pick haptic feedback, copy-listing success haptic routing, delete-history warning haptic feedback, camera capture failure feedback copy, accessible-border contrast token selection, optional accessibility hint guardrails, static font variant registration, Bold Text font-face switching, anti-pattern architecture, sensitive logging, and tone-word copy guardrails, icon-button tap-target minimums, iOS 17 deployment, required runtime metadata, photo-library permission absence guardrails, iPhone portrait plist coverage, iPhone landscape rotation usability guard, fixed white branded-font launch/splash wordmark parity, app config secret-handling, root-only HTTPS Supabase URL/anon-key validation, target-exclusion guardrails, privacy manifest data-use/required-reason coverage and packaging guardrails, Sign in with Apple entitlement and app-target signing metadata guardrails, one-time guest-to-account history migration paths, real-device preflight script coverage, and App Store screenshot capture evidence, and the no-sign Release iPhoneOS archive verifier compiles, validates package metadata, and checks a 3208KB app bundle against the 20 MB budget. The support/privacy site is built, saved, publicly deployed, and verified with unauthenticated 200 responses for support, privacy, and terms pages; iPhone App Store screenshots are captured, and the App Store metadata evidence verifier passes against the recorded product-page fields. A signed archive, App Store Connect IPA export, App Store Connect validation, App Store Connect legal/account-owner confirmation, backend smoke preflight, and Instruments pass are blocked until an Apple development team, App Store Connect API-key credentials, confirmed account-owner/product-page metadata, real Supabase config, and trusted physical hardware are available; real-device acceptance pass remains blocked until the acceptance evidence table is recorded.
