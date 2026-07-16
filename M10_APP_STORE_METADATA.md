# M10 App Store Metadata Evidence

This file records the App Store Connect metadata that must be ready before final submission. It is separate from the signed binary checks: the archive can validate while the product page, app privacy answers, screenshots, support URL, and review notes are still incomplete.

Every required field below must be concrete before `Scripts/verify_m10_app_store_metadata.sh` can pass. Do not replace `TBD` with generic "passed" notes.

## Required App Information

| Field | Value |
| --- | --- |
| App name | BuySell AI |
| Bundle ID | com.rhodes.buysellai |
| SKU | TBD |
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
| App Review notes | TBD |

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

## Commands

Verify this file before final submission:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

Until the App Store Connect metadata, screenshots, URLs, and account-owner answers are complete, record the known blocker:

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```
