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
- M10 QA: partial. 86 unit/UI tests pass in simulator, including offline analyze retry/toast, API/auth/history/account timeout, non-2xx, rate-limit, retry mapping, Apple auth token-exchange timeout/rate-limit/retry mapping, remote history optimistic rollback and mapped toast coverage, decoded-response malformed JSON mapping, exact clipboard-copy, settings preference persistence, marketplace catalog parity, marketplace localization parity, marketplace VoiceOver payout labels, Snap Result edit committing, Snap Result retry loading hint scoping, listing regeneration attempt scoping, flow transition stale-presentation cancellation, image downscale pixel sizing, Apple user ID Keychain persistence, marketplace-pick haptic feedback, copy-listing success haptic routing, delete-history warning haptic feedback, camera capture failure feedback copy, accessible-border contrast token selection, static font variant registration, Bold Text font-face switching, anti-pattern architecture and tone-word copy guardrails, icon-button tap-target minimums, iPhone portrait plist coverage, app config secret-handling guardrails, guest history relaunch persistence, and one-time guest-to-account history migration paths, and a no-sign Release iPhoneOS archive compiles and validates with a 3.0 MB app bundle. A signed archive is blocked until an Apple development team is configured; real-device acceptance pass remains.
