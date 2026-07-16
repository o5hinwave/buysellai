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
bash Scripts/preflight_m10_signed_archive.sh /tmp/BuySellAI-signed.xcarchive
```

App Store Connect export preflight:

```sh
bash Scripts/preflight_m10_app_store_export.sh /tmp/BuySellAI-appstore.xcarchive /tmp/BuySellAI-appstore-export
```

App Store Connect validation preflight after export and API-key setup:

```sh
ASC_API_KEY_ID=<key-id> \
ASC_API_ISSUER_ID=<issuer-id> \
ASC_API_PRIVATE_KEYS_DIR=<directory-containing-AuthKey_key-id.p8> \
bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export
```

Until the Apple team, exported IPA, and App Store Connect API-key credentials are available, record the known blockers:

```sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_signed_archive.sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_app_store_export.sh
ALLOW_MISSING_ASC=1 bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export
```

Real-device preflight after connecting a trusted iPhone or iPad with Developer Mode enabled:

```sh
bash Scripts/preflight_m10_real_device.sh
```

To target a specific connected device:

```sh
DEVICE_ID=<devicectl-identifier> bash Scripts/preflight_m10_real_device.sh
```

Until a trusted physical device is connected, record the known hardware blocker:

```sh
ALLOW_MISSING_DEVICE=1 bash Scripts/preflight_m10_real_device.sh
```

Real-device acceptance evidence check after the manual device pass:

```sh
bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Each real-device acceptance Evidence cell must include the observed proof terms documented in `M10_ACCEPTANCE.md`; generic "passed" notes are intentionally rejected.

Until the manual device pass is complete, record the known acceptance blocker:

```sh
ALLOW_PENDING_ACCEPTANCE=1 bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Secret-pattern scan:

```sh
bash Scripts/scan_m10_secrets.sh
```

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

Each Instruments criteria Evidence cell must include the observed proof terms documented in `M10_INSTRUMENTS.md`; generic "passed" notes are intentionally rejected.

Until signed physical-device Instruments profiling is complete, record the known profiler blocker:

```sh
ALLOW_PENDING_INSTRUMENTS=1 bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

Combined M10 submit-readiness evidence gate:

```sh
bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

Until every signed archive, App Store, real-device, and manual evidence item is complete, record the known readiness blocker:

```sh
ALLOW_PENDING_M10=1 bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

The no-sign archive verifier validates the Release iPhoneOS build, privacy/package metadata, camera-only permissions, and the `<20 MB` app bundle target. A fully signed App Store archive, App Store Connect IPA export, and App Store Connect validation still require selecting a real Apple development team in Xcode and providing App Store Connect API-key credentials.

Track final signed-archive and real-device acceptance in `M10_ACCEPTANCE.md`.

## Assumptions

- Supabase project values were not present in the blank repository. The API client is implemented against the requested `analyze-image` and `generate-listing` contracts, and the app shows friendly configuration errors until `Config.plist` is supplied.
- Supabase Auth must have Apple enabled for full server-backed Sign in with Apple. Without backend config, Apple sign-in still stores the Apple user identifier locally and leaves guest history local.
- Space Grotesk and Inter static font faces are bundled from Google Fonts under the Open Font License and registered through `UIAppFonts`; Inter Bold is included so Bold Text can switch body copy to a true bold face.
- Sign in with Apple has a native nonce-based coordinator, Supabase token exchange, Keychain token persistence, and guest-to-account history migration. Delete account is wired to a `delete-account` Edge Function and still requires that backend function to be deployed.
- `Config.plist.example` is kept in the repo for setup instructions but excluded from the app target so placeholder backend values are not shipped in the bundle.
- Real-device camera latency, Accessibility Inspector contrast checks, signed App Store archive validation, the signed-archive and App Store export preflights without `ALLOW_MISSING_TEAM=1`, the App Store validation preflight without `ALLOW_MISSING_ASC=1`, the real-device preflight without `ALLOW_MISSING_DEVICE=1`, the real-device acceptance evidence check without `ALLOW_PENDING_ACCEPTANCE=1`, the Instruments evidence check without `ALLOW_PENDING_INSTRUMENTS=1`, and the combined submit-readiness gate without `ALLOW_PENDING_M10=1` still need physical-device/account QA. The performance evidence verifier covers only repeatable simulator and package-size evidence; final Time Profiler and Allocations evidence is tracked separately in `M10_INSTRUMENTS.md`.

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
- M10 QA: partial. 296 unit/UI tests pass in simulator, including localized Snap Result price-editing coverage, repeatable hidden-file secret scan guardrails, repeatable signed-archive preflight guardrails, repeatable App Store export preflight guardrails, repeatable App Store validation preflight guardrails, repeatable real-device preflight guardrails, repeatable real-device acceptance evidence guardrails, repeatable combined submit-readiness guardrails, repeatable performance evidence guardrails, repeatable Instruments evidence guardrails, repeatable no-sign archive/package-size verifier coverage, numeric light/dark contrast-token coverage, readable orange foreground-token guardrails, offline analyze retry/toast, listing-generation offline toast/regenerate coverage, listing error-state copy-action guardrails, selectable listing text panel and sticky listing action guardrails, analyze-response follow-up/tax field ignore coverage, anonymous analyze/listing request-shape coverage, camera shutter-to-offline-analyze thumbnail/error path, simulator shutter-to-result thumbnail budget guard, camera permission-denied settings fallback, camera ready-overlay VoiceOver labels, camera-only no photo-picker guard, camera capture orientation rotation mapping, camera back-only selection fallback guardrails, camera viewfinder 24-point inset and 3:4 aspect guardrails, camera torch/flash availability guardrails, camera configuration lock/unlock guardrails, camera configuration scoped-commit guardrails, camera preview freeze-before-downscale guardrails, dismissal-safe capture-to-result state transition with thumbnail data, API/auth/history/account timeout, non-2xx, rate-limit, retry, DNS/host/connect offline mapping, and delete-account offline mapping, generate-listing signed request and price payload coverage, generate-listing route-level timeout/offline/rate-limit/non-2xx/retry/malformed-response mapping, Apple auth token-exchange Supabase identity separation, refresh-token preservation, refresh-session non-2xx/timeout/offline/rate-limit/retry/malformed-response mapping, auth network-lost retry coverage across Apple, email, and refresh routes, Apple auth non-2xx mapping, signed-in Home refresh replacing history from remote rows, stale remote refresh protection after a newly saved listing, stale sign-in migration/fetch protection after sign-out or a newly saved listing, stale remote save/delete/clear completion guards after sign-out or newer history changes, delete-account success/failure state cleanup coverage, delete-account network-lost retry coverage, remote history fetch/upsert/delete/clear route-level error/retry coverage, remote history both 5xx and network-lost retry coverage, remote history optimistic rollback and mapped toast coverage, decoded-response malformed JSON mapping, optional auth dismissal with guest snap continuity, exact clipboard-copy, settings preference persistence, settings preference-control VoiceOver labels, settings grouped-list styling, settings section-limit and gated danger-zone guardrails, explicit settings close control, settings About in-app Safari guardrails, dark-mode Home-to-Listing flow navigation, app-level Reduce Motion propagation through animated surfaces, screen-transition timing, root sheet presentation guardrails, 300 ms splash timing guardrails, skeleton shimmer reduce-motion guardrails, slow history refresh not blocking Home launch, 500-row Home history UI scroll guard, simulator Home launch budget guard, simulator camera-ready overlay budget guard, accessibility3 Home primary-action reachability, Home display headline multiline scaling guard, Home header sign-in tap-target minimum, Home gear 40-point visual tap-target guardrails, Home primary-glow elevation-token scoping, Home re-opening the How it works tutorial, settings re-opening the How it works tutorial, tutorial custom illustration guardrails, tutorial step-value accessibility guardrails, tutorial next/get-started walkthrough, tutorial swipe navigation, tutorial keyboard navigation guardrails, auth email sign-in navigation-push guardrails, auth provider button-height guardrails, auth period-free BuySell AI wordmark guardrails, settings clear-history confirmation and removal, delete-account typed confirmation gating, delete-account VoiceOver label coverage, source-wide Button accessibility-label guardrails, marketplace catalog parity, marketplace estimate Codable round-trip and Decimal-preserving payout coverage, marketplace localization parity, marketplace brand-tint design-token guardrails, source localization-key coverage, SwiftUI localization-wrapper guardrails, model display-copy localization coverage, Decimal currency-formatting precision guardrails, marketplace VoiceOver payout labels, presented-sheet VoiceOver sort-priority coverage, VoiceOver critical-path UI label coverage from Home through Copy, Snap Result chip VoiceOver labels and action hints, Snap Result still-working alert announcement guardrails, Snap Result error action ordering, tokenized pure black/white SwiftUI color guardrails, chip-button tap-target minimums, ghost-button pill shape guardrails, marketplace summary direct-listing navigation, Snap Result edit committing, Snap Result retry loading hint scoping, Snap Result stale retry protection, cancellation-friendly analyze/listing copy, listing regeneration attempt scoping, listing retake preserving the selected marketplace, recent listing reopen skipping the marketplace picker, flow transition stale-presentation cancellation, image downscale pixel sizing, local save thumbnail persistence, exact decimal local price persistence, guest history relaunch persistence with newest-first ordering, recent listing working-thumbnail status in the copy/relaunch UI flow, Apple user ID Keychain persistence, AuthSession identity coverage, signed-in relaunch remote-history hydration coverage, analysis success/failure haptic routing, marketplace-pick haptic feedback, copy-listing success haptic routing, delete-history warning haptic feedback, camera capture failure feedback copy, accessible-border contrast token selection, optional accessibility hint guardrails, static font variant registration, Bold Text font-face switching, anti-pattern architecture, sensitive logging, and tone-word copy guardrails, icon-button tap-target minimums, iOS 17 deployment, required runtime metadata, photo-library permission absence guardrails, iPhone portrait plist coverage, iPhone landscape rotation usability guard, fixed white branded-font launch/splash wordmark parity, app config secret-handling, root-only HTTPS Supabase URL/anon-key validation, and target-exclusion guardrails, privacy manifest data-use/required-reason coverage and packaging guardrails, Sign in with Apple entitlement and app-target signing metadata guardrails, one-time guest-to-account history migration paths, and real-device preflight script coverage, and the no-sign Release iPhoneOS archive verifier compiles, validates package metadata, and checks a 3188KB app bundle against the 20 MB budget. A signed archive, App Store Connect IPA export, App Store Connect validation, and Instruments pass are blocked until an Apple development team, App Store Connect API-key credentials, and trusted physical hardware are available; real-device acceptance pass remains blocked until the acceptance evidence table is recorded.
