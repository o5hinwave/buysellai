# M10 App Store Metadata Evidence

This file records the App Store Connect metadata that must be ready before final submission. It is separate from the signed binary checks: the archive can validate while the product page, app privacy answers, screenshots, support URL, and review notes are still incomplete.

Every required field below must be concrete before `Scripts/verify_m10_app_store_metadata.sh` can pass. Do not replace `TBD` with generic "passed" notes.

## Required App Information

| Field | Value |
| --- | --- |
| App name | BuySell AI |
| Bundle ID | com.rhodes.buysellai |
| SKU | buysell-ai-ios |
| Primary language | English (U.S.) |
| Primary category | Shopping |
| Secondary category | Lifestyle |
| Age rating | TBD |
| Made for Kids | No |
| DSA trader status | TBD |
| License agreement | Apple Standard EULA |

## Version Metadata

| Field | Value |
| --- | --- |
| Version number | 1.0 |
| Copyright | TBD |
| Subtitle | Snap. Pick. Sell. |
| Promotional text | Turn stuff into cash in three taps. |
| Description | Snap a photo of anything you want to sell. BuySell AI identifies the item, estimates a fair price, ranks common marketplaces, and writes a copy-ready listing you can paste into the marketplace you choose. Sign-in is optional, and guest history stays on device. |
| Keywords | resale,garage sale,marketplace,camera,listings,declutter |
| Support URL | TBD |
| Marketing URL | N/A |
| Privacy Policy URL | TBD |
| Screenshots | TBD |
| App Review notes | Reviewer path: launch BuySell AI, continue as a guest if prompted, grant camera access, capture a household item, choose a marketplace, review the generated listing, and copy the result. Sign in with Apple is optional for account history. Supabase Edge Functions provide item analysis and listing generation; no demo credentials are required for the guest flow. |

## App Privacy Answers

| Field | Value |
| --- | --- |
| Privacy Policy URL | TBD |
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
| Saved version | appgprj_6a590c444ddc819199896a5205d985d8~appgver_c5fbf72345a481918d56a7881b0addaf |
| Version number | 1 |
| Source commit | 752e7310c38df585eab036205f8500c630de4f1f |
| Source path | AppStoreSite |
| Local verification | `npm test`; `npm run lint` |
| Deployment status | Private Sites deployment appgdep_6a590cf4dd60819186a89f4264dabf14 succeeded at https://buysell-ai-support.o5hinwavve.chatgpt.site, but unauthenticated `/support` and `/privacy` requests return HTTP 401. |
| Public App Store URL status | Pending: App Store support/privacy URLs must be public before these metadata fields can pass. |

## Commands

Verify this file before final submission:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

Until the App Store Connect metadata, screenshots, URLs, and account-owner answers are complete, record the known blocker:

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```
