# M10 App Store Metadata Evidence

This file records the App Store Connect product-page, privacy, accessibility, screenshot, review, and legal fields that must be complete before BuySell AI can be submitted. It intentionally keeps owner/legal-only fields pending until the App Store Connect account owner confirms them.

## App Store Connect metadata

| Field | Value |
| --- | --- |
| App name | BuySell AI |
| Bundle ID | com.despia.buysellai |
| Version number | 1.0 |
| SKU | buysell-ai-ios |
| Primary language | English (U.S.) |
| Primary category | Shopping |
| Subtitle | Turn any photo into a listing |
| Made for Kids | No |
| License agreement | Apple's standard End User License Agreement |
| Copyright | © 2026 RHODES MCALLEN COONS COONS |
| Content rights | The app ships original UI, copy, screenshots, icon assets, and support-site text from this repository; users provide their own item photos and listing content. |
| Age rating | 4+ - current app content has no public feed, unrestricted web browsing, gambling, medical guidance, mature content, user-to-user checkout, or regulated-goods sale flow; camera and photo access are used only to prepare item listings. |
| Export compliance | `ITSAppUsesNonExemptEncryption=false`; current app code uses standard HTTPS/URLSession to Supabase and Apple endpoints, Keychain storage, and SHA-256 nonce hashing for Sign in with Apple, with no custom non-exempt encryption implementation present. |
| DSA trader status | Pending - App Store Connect account owner must confirm Digital Services Act trader status before submission. |
| Account owner legal confirmation | Pending - App Store Connect account owner must enter the final submission confirmation covering DSA trader status, privacy answers, review contact ownership, and the recorded copyright, age rating, and export compliance fields. |
| Keywords | sell,resale,marketplace,listing,camera,declutter,garage,used |
| Promotional text | Snap it. Price it. Sell it. Take a picture and BuySell turns it into a clear marketplace plan. |
| Description | BuySell AI helps people sell almost anything from a photo. Snap a picture, answer a few simple questions, see real marketplace evidence, compare likely proceeds and fees, then copy a polished listing for the place you choose. |
| App Review notes | BuySell supports guest use and Sign in with Apple. Launch the app, choose the guest path if prompted, grant Camera permission, tap Snap to sell, capture an item, confirm the result, choose a marketplace, and copy the listing. Supabase Edge Functions provide item analysis and listing generation when `Config.plist` points at the production Supabase project. |
| Support URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/support |
| Privacy Policy URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/privacy |
| Accessibility URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/accessibility |
| Terms URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/terms |
| Marketing URL | https://buysell-ai-support.o5hinwavve.chatgpt.site |

## Screenshots

| Field | Value |
| --- | --- |
| Screenshots | AppStoreAssets/Screenshots/iPhone-16-Pro-Max/01-home.png, AppStoreAssets/Screenshots/iPhone-16-Pro-Max/02-result.png, AppStoreAssets/Screenshots/iPhone-16-Pro-Max/03-marketplaces.png, AppStoreAssets/Screenshots/iPhone-16-Pro-Max/04-listing.png, AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/01-home.png, AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/02-result.png, AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/03-marketplaces.png, AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/04-listing.png |
| Screenshot sets | iPhone 6.9, iPad 13 |
| iPhone 6.9 screenshot directory | AppStoreAssets/Screenshots/iPhone-16-Pro-Max/ |
| iPad 13 screenshot directory | AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4/ |
| Screenshot dimensions | iPhone 6.9 1320x2868; iPad 13 2064x2752 |
| Screenshot files | 8 |
| Screenshot quality | No blank or dark-strip artifacts; warm orange brand signal present. |
| Screenshot brand signal | warm orange present |
| iPhone 6.9 result bundle | /tmp/buysell-m10-screenshots-iphone-16-pro-max-apple-card-20260723.xcresult |
| iPad 13 result bundle | /tmp/buysell-m10-screenshots-ipad-pro-13-apple-card-20260723.xcresult |
| Screenshot result bundle | /tmp/buysell-submit-readiness-full.xcresult |
| Screenshot capture test | BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured() |

## App Privacy Data Types

| Field | Value |
| --- | --- |
| App privacy data types | Email Address, User ID, Photos or Videos, Other User Content |
| Tracking | No tracking. No tracking domains are declared in `PrivacyInfo.xcprivacy`. |
| Data use | App functionality only. Images are sent to Supabase Edge Functions for item analysis, and listing text/history are used to provide and sync the selling flow. |
| Linked to user | User ID and synced history are linked only after optional sign-in. Guest usage remains local unless the person signs in. |
| Data linked to user | Yes |
| Data used for tracking | No |
| Tracking domains | None |
| Data use purpose | App Functionality |
| Account deletion | Delete account is available in Settings for signed-in accounts, with a typed confirmation before the backend delete-account function is called. |
| Third-party advertising | None |

## Accessibility Nutrition Labels

| Field | Value |
| --- | --- |
| Accessibility labels | iPhone and iPad Accessibility Nutrition Labels: VoiceOver, Larger Text, Dark Interface, Sufficient Contrast, Reduced Motion, and Differentiate Without Color are covered across Home, Camera, Snap Result, Marketplace Picker, Listing, Auth, Settings, and destructive actions. |
| Accessibility common tasks | First launch, optional sign in, guest flow, snap with camera, review result, choose marketplace, copy listing, reopen history, delete account history, manage settings, and delete account. |
| Accessibility evidence | VoiceOver, Dynamic Type, dark mode, contrast, Reduce Motion, Differentiate Without Color, Bold Text, Reduce Transparency, and 44-point tap-target guardrails are recorded in `M10_ACCEPTANCE.md` and simulator result bundles. |
| Accessibility URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/accessibility |
| Claimed features | VoiceOver, Larger Text, Reduced Motion, Bold Text, Reduce Transparency |
| Common tasks | Launch, continue as guest, snap an item, confirm the result, choose a marketplace, copy listing text, reopen history, delete history, and manage settings. |
| Exclusions | Voice Control is intentionally excluded until a real-device Voice Control pass is recorded. |

## Verification

Run the metadata verifier with pending mode while account-owner legal fields remain incomplete:

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md \
  | tee /tmp/buysell-submit-readiness-app-store-metadata.log
```

The verifier intentionally keeps metadata pending until the account owner confirms DSA trader status, review contact ownership, privacy answers, and final App Store Connect legal fields.
