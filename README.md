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
- Space Grotesk and Inter TTF files were not present. Font calls use the requested custom names and fall back through iOS font resolution until the TTFs are added to `Resources/Fonts` and `UIAppFonts`.
- Sign in with Apple has a native coordinator and Keychain persistence. Supabase account migration and delete-account calls are marked `TODO(agent): needs backend`.
- Real-device camera latency, Accessibility Inspector contrast checks, and App Store archive validation still need physical-device QA.

## Milestone Status

- M1 Skeleton: built. Xcode project, design tokens, typography, launch screen, Home shell.
- M2 Camera: built. AVCapture preview, permission handling, torch, capture, downscale.
- M3 Analyze: built. API client contract, loading/success/error result sheet, inline editing.
- M4 Marketplace picker: built. Full marketplace list, metadata, fee table, estimator, sticky summary.
- M5 Listing: built. API contract, listing sheet, copy, haptics, toast.
- M6 History: built. SwiftData guest persistence, Home list, delete, reopen listing.
- M7 Auth: partially built. Native optional auth UI and Apple sign-in shell; server sync/migration stubbed.
- M8 Tutorial: built. Five-slide first-launch walkthrough with swipe and reduce-motion support.
- M9 Settings + polish: built. Theme, reduce motion, history clearing, about links, account actions.
- M10 QA: partial. Unit and UI tests pass in simulator; real-device acceptance pass remains.

