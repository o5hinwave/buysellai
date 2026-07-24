# Apple Today Feature Nomination Package

This file keeps the App Store editorial pitch ready for App Store Connect Featuring Nominations. It does not guarantee placement; Apple editorial review is discretionary. Use this package after the signed binary, App Store metadata, backend, real-device, and legal gates are complete.

## Apple Guidance

| Field | Value |
| --- | --- |
| App Store Connect path | Featuring Nominations in App Store Connect |
| Apple guidance source | https://developer.apple.com/app-store/getting-featured/ |
| App Store Connect help source | https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/ |
| Submission lead time | Submit at least two weeks before the desired feature window; submit up to three months in advance for wider featuring consideration. |
| Required App Store Connect role | Account Holder, Admin, App Manager, or Marketing |

## Nomination Copy

| Field | Value |
| --- | --- |
| App | BuySell AI |
| Platform | iOS and iPadOS |
| Nomination type | New app launch |
| Preferred placement | Today tab and Apps tab editorial consideration |
| Feature title | Sell anything in three taps |
| One-line story | BuySell AI turns a photo of a household item into a priced, copy-ready marketplace listing. |
| Editorial angle | A calm, camera-first resale assistant for people who avoid resale apps because they feel crowded, confusing, or too much work. |
| Why now | The native SwiftUI 1.0 launch replaces the web experience with a focused iPhone flow: snap a photo, confirm what it is, pick the best marketplace, and copy the listing. |
| New content/functionality | Full-screen AVFoundation camera capture, image downscaling, Supabase Edge Function analysis, a short item-details review step, marketplace payout ranking, grounded marketplace listing research, generated listing copy, optional Sign in with Apple sync, guest SwiftData history, and a concise first-launch guide. |
| Technology quality | Built with SwiftUI, Observation, AVFoundation, SwiftData, StoreKit, AuthenticationServices, async/await networking, semantic privacy metadata, native materials, Dynamic Type, and Reduce Motion support. |
| Accessibility story | VoiceOver labels and sheet order, Larger Text through accessibility3, Bold Text font variants, sufficient contrast, Reduced Motion, Reduce Transparency, Differentiate Without Color borders, and 44-point tap targets are covered by simulator/source guardrails. |
| Privacy story | Guest use works without sign-in; account sync is optional; images and listing text are used for app functionality; no tracking domains are declared; provider secrets stay in Supabase Edge Function secrets, not in the iOS app bundle. |
| Screenshots | iPhone 6.9-inch and iPad 13-inch App Store screenshot sets are retained at `AppStoreAssets/Screenshots/iPhone-16-Pro-Max/` and `AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/`. |
| Support URLs | Public support, privacy, accessibility, and terms pages are recorded in `M10_APP_STORE_METADATA.md`. |
| Reviewer path | Launch BuySell AI, continue as a guest, tap Snap to sell, capture an item, confirm the result, choose a marketplace, and copy the generated listing. |

## Asset Checklist

| Field | Value |
| --- | --- |
| App icon | Text-free camera-first 1024x1024 non-alpha PNG in `BuySellAI/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. |
| Product screenshots | Four iPhone 6.9-inch screenshots and four iPad 13-inch screenshots show Home, result review, marketplace ranking, and listing copy. |
| Visual signal | Screenshots and icon carry the warm BuySell orange brand signal with no loud gradients, no generic dashboard layouts, and no placeholder text. |
| Accessibility evidence | Current evidence is recorded in `M10_ACCEPTANCE.md` and `M10_APP_STORE_METADATA.md`; final physical-device evidence is still required before submission. |

## Submission Notes

Use this copy when an Account Holder, Admin, App Manager, or Marketing user creates the nomination in App Store Connect. Update the desired feature window to match the final signed release date, attach the retained screenshots or App Store Connect product page assets, and submit only after the M10 submit-readiness gate is green.
