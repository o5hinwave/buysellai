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

Keep AI provider secrets, including Gemini keys, out of the iOS bundle. Add them to the Supabase Edge Function environment instead, then let the app call the existing `analyze-image` and `generate-listing` functions through Supabase.

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

## Verify

```sh
xcodebuild test \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
```

## Assumptions

- Supabase project values were not present in the blank repository. The API client is implemented against the requested `analyze-image` and `generate-listing` contracts, and the app shows friendly configuration errors until `Config.plist` is supplied.
- Supabase Auth must have Apple enabled for full server-backed Sign in with Apple. Without backend config, Apple sign-in still stores the Apple user identifier locally and leaves guest history local.
- Space Grotesk and Inter are bundled from Google Fonts under the Open Font License and registered through `UIAppFonts`.
- Sign in with Apple has a native nonce-based coordinator, Supabase token exchange, Keychain token persistence, and guest-to-account history migration. Delete-account remains `TODO(agent): needs backend`.
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
- M9 Settings + polish: built. Theme, reduce motion, history clearing, about links, account actions.
- M10 QA: partial. Unit and UI tests pass in simulator; real-device acceptance pass remains.
