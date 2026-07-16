# M10 App Store Metadata Evidence

This file records the App Store Connect metadata that must be ready before final submission. It is separate from the signed binary checks: the archive can validate while the product page, app privacy answers, screenshots, support URL, and review notes are still incomplete.

Every required field below must be concrete before `Scripts/verify_m10_app_store_metadata.sh` can pass. Do not replace `TBD` with generic "passed" notes. Filled-in Support URL and Privacy Policy URL values must be public HTTPS pages reachable without authentication.

## Required App Information

| Field | Value |
| --- | --- |
| App name | BuySell AI |
| Bundle ID | com.rhodes.buysellai |
| SKU | buysell-ai-ios |
| Primary language | English (U.S.) |
| Primary category | Shopping |
| Secondary category | Lifestyle |
| Age rating | 4+ (No objectionable content; camera/listing utility.) |
| Made for Kids | No |
| DSA trader status | Not a trader (assumption: individual App Store account owner is not acting as a business for this app; confirm in App Store Connect before submission.) |
| License agreement | Apple Standard EULA |

## Version Metadata

| Field | Value |
| --- | --- |
| Version number | 1.0 |
| Copyright | 2026 Rhodes |
| Subtitle | Snap. Pick. Sell. |
| Promotional text | Turn stuff into cash in three taps. |
| Description | Snap a photo of anything you want to sell. BuySell AI identifies the item, estimates a fair price, ranks common marketplaces, and writes a copy-ready listing you can paste into the marketplace you choose. Sign-in is optional, and guest history stays on device. |
| Keywords | resale,garage sale,marketplace,camera,listings,declutter |
| Support URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/support |
| Marketing URL | N/A |
| Privacy Policy URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/privacy |
| Screenshots | iPhone screenshot evidence captured on iPhone 16 Pro simulator, iOS 18.6: `AppStoreAssets/Screenshots/iPhone-16-Pro/01-home.png`, `02-result.png`, `03-marketplaces.png`, `04-listing.png`. |
| App Review notes | Reviewer path: launch BuySell AI, continue as a guest if prompted, grant camera access, capture a household item, choose a marketplace, review the generated listing, and copy the result. Sign in with Apple is optional for account history. Supabase Edge Functions provide item analysis and listing generation; no demo credentials are required for the guest flow. |

## Screenshot Evidence

| Field | Value |
| --- | --- |
| Device | iPhone 16 Pro simulator |
| iOS | 18.6 |
| Dimensions | 1206 x 2622 PNG |
| Files | `AppStoreAssets/Screenshots/iPhone-16-Pro/01-home.png`, `02-result.png`, `03-marketplaces.png`, `04-listing.png` |
| Capture test | `BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured` |
| Result bundle | `/tmp/buysell-submit-readiness-full.xcresult` |
| Result | Passed as part of the retained full simulator suite `/tmp/buysell-submit-readiness-full.xcresult` with 316 tests and 0 failures on 2026-07-16; standalone screenshot bundle `/tmp/buysell-m10-screenshots.xcresult` is also retained. |

## App Privacy Answers

| Field | Value |
| --- | --- |
| Privacy Policy URL | https://buysell-ai-support.o5hinwavve.chatgpt.site/privacy |
| App privacy data types | Email Address, User ID, Photos or Videos, Other User Content |
| Data linked to user | Yes |
| Data used for tracking | No |
| Tracking domains | None |
| Data use purpose | App Functionality |
| User privacy choices URL | N/A |
| Account deletion | Yes, Settings -> Danger zone -> Delete account calls the delete-account Edge Function. |
| Export compliance | ITSAppUsesNonExemptEncryption=false; app uses only standard HTTPS/TLS. |

## Support And Privacy Site Evidence

| Field | Value |
| --- | --- |
| Sites project ID | appgprj_6a590c444ddc819199896a5205d985d8 |
| Saved version | appgprj_6a590c444ddc819199896a5205d985d8~appgver_eba3c742747c8191ae3e04479bd74453 |
| Version number | 3 |
| Source commit | 2cbaf9521ecb2848d4ef9c321670dc8968055f34 |
| Source path | AppStoreSite |
| Local verification | `npm test`; `npm run lint` |
| Deployment status | Sites deployment appgdep_6a592201306c81919134801e11be8f2c succeeded at https://buysell-ai-support.o5hinwavve.chatgpt.site; site access changed to public on 2026-07-16. |
| Public App Store URL status | Verified 2026-07-16: unauthenticated `curl -L` requests return HTTP 200 for `/support`, `/privacy`, and `/terms`. |

## Commands

Verify this file before final submission:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

Until the App Store Connect metadata, screenshots, URLs, and account-owner answers are complete, record the known blocker:

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```
