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

Keep AI provider secrets, including Gemini keys, out of the iOS bundle. Add them to the Supabase Edge Function environment instead, using the variable name expected by the deployed functions (commonly `GEMINI_API_KEY`), then let the app call the existing `analyze-image` and `generate-listing` functions through Supabase.

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
xcodebuild archive \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/BuySellAI-nosign.xcarchive \
  CODE_SIGNING_ALLOWED=NO
```

The no-sign archive validates the Release iPhoneOS build and package contents. A fully signed App Store archive still requires selecting a real Apple development team in Xcode.

## Assumptions

- Supabase project values were not present in the blank repository. The API client is implemented against the requested `analyze-image` and `generate-listing` contracts, and the app shows friendly configuration errors until `Config.plist` is supplied.
- Supabase Auth must have Apple enabled for full server-backed Sign in with Apple. Without backend config, Apple sign-in still stores the Apple user identifier locally and leaves guest history local.
- Space Grotesk and Inter static font faces are bundled from Google Fonts under the Open Font License and registered through `UIAppFonts`; Inter Bold is included so Bold Text can switch body copy to a true bold face.
- Sign in with Apple has a native nonce-based coordinator, Supabase token exchange, Keychain token persistence, and guest-to-account history migration. Delete account is wired to a `delete-account` Edge Function and still requires that backend function to be deployed.
- `Config.plist.example` is kept in the repo for setup instructions but excluded from the app target so placeholder backend values are not shipped in the bundle.
- Real-device camera latency, Accessibility Inspector contrast checks, and App Store archive validation still need physical-device QA.

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
- M10 QA: partial. 157 unit/UI tests pass in simulator, including offline analyze retry/toast, listing-generation offline toast/regenerate coverage, listing error-state copy-action guardrails, analyze-response follow-up/tax field ignore coverage, anonymous analyze/listing request-shape coverage, camera shutter-to-offline-analyze thumbnail/error path, simulator shutter-to-result thumbnail budget guard, camera permission-denied settings fallback, camera ready-overlay VoiceOver labels, camera-only no photo-picker guard, camera capture orientation rotation mapping, camera configuration lock/unlock guardrails, dismissal-safe capture-to-result state transition with thumbnail data, API/auth/history/account timeout, non-2xx, rate-limit, retry, and delete-account offline mapping, generate-listing signed request and price payload coverage, Apple auth token-exchange timeout/rate-limit/retry/malformed-response mapping, signed-in Home refresh replacing history from remote rows, stale remote refresh protection after a newly saved listing, stale sign-in migration/fetch protection after sign-out or a newly saved listing, stale remote save/delete/clear completion guards after sign-out or newer history changes, delete-account success/failure state cleanup coverage, remote history optimistic rollback and mapped toast coverage, decoded-response malformed JSON mapping, optional auth dismissal with guest snap continuity, exact clipboard-copy, settings preference persistence, settings preference-control VoiceOver labels, explicit settings close control, dark-mode Home-to-Listing flow navigation, app-level Reduce Motion propagation through animated surfaces, slow history refresh not blocking Home launch, 500-row Home history UI scroll guard, simulator Home launch budget guard, simulator camera-ready overlay budget guard, accessibility3 Home primary-action reachability, Home display headline multiline scaling guard, Home header sign-in tap-target minimum, Home re-opening the How it works tutorial, settings re-opening the How it works tutorial, tutorial custom illustration guardrails, tutorial next/get-started walkthrough, tutorial swipe navigation, tutorial keyboard navigation guardrails, settings clear-history confirmation and removal, delete-account typed confirmation gating, delete-account VoiceOver label coverage, marketplace catalog parity, marketplace estimate Codable round-trip coverage, marketplace localization parity, source localization-key coverage, model display-copy localization coverage, marketplace VoiceOver payout labels, presented-sheet VoiceOver sort-priority coverage, Snap Result chip VoiceOver labels and action hints, Snap Result still-working alert announcement guardrails, chip-button tap-target minimums, marketplace summary direct-listing navigation, Snap Result edit committing, Snap Result retry loading hint scoping, Snap Result stale retry protection, cancellation-friendly analyze/listing copy, listing regeneration attempt scoping, listing retake preserving the selected marketplace, recent listing reopen skipping the marketplace picker, flow transition stale-presentation cancellation, image downscale pixel sizing, local save thumbnail persistence, exact decimal local price persistence, guest history relaunch persistence with newest-first ordering, recent listing working-thumbnail status in the copy/relaunch UI flow, Apple user ID Keychain persistence, AuthSession identity coverage, marketplace-pick haptic feedback, copy-listing success haptic routing, delete-history warning haptic feedback, camera capture failure feedback copy, accessible-border contrast token selection, optional accessibility hint guardrails, static font variant registration, Bold Text font-face switching, anti-pattern architecture and tone-word copy guardrails, icon-button tap-target minimums, iOS 17 deployment, required runtime metadata, iPhone portrait plist coverage, iPhone landscape rotation usability guard, fixed white launch/splash wordmark parity, app config secret-handling guardrails, and one-time guest-to-account history migration paths, and a no-sign Release iPhoneOS archive compiles and validates with a 3.0 MB app bundle. A signed archive is blocked until an Apple development team is configured; real-device acceptance pass remains.
