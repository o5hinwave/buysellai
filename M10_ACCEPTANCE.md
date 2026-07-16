# M10 Acceptance Checklist

This checklist tracks the remaining submit-readiness work for BuySell AI iOS. Simulator tests and no-sign archives are useful evidence, but v1 is not complete until the signed archive and real-device checks below are recorded.

## Current Evidence

- Simulator suite: `284` unit/UI tests pass on iPhone 16 Pro simulator, iOS 18.6.
- No-sign Release iPhoneOS archive: compiles and packages a `3.1M` app bundle.
- Binary-size check: archived app bundle stays under `20 MB`.
- Package checks: `PrivacyInfo.xcprivacy` is present, camera permission metadata is present, photo-library permission metadata is absent.
- Secret scan: no Gemini/OpenAI-style provider secret patterns are present in repo text files outside generated bundles.
- Latest local evidence: focused submit-readiness preflight result bundle `/tmp/buysell-submit-readiness-focused.xcresult`, full-suite result bundle `/tmp/buysell-submit-readiness-full.xcresult`, no-sign archive `/tmp/buysell-submit-readiness-nosign.xcarchive`, verifier log `/tmp/buysell-submit-readiness-nosign.log`, signed-preflight blocker log `/tmp/buysell-submit-readiness-signed-preflight.log`, App Store export blocker log `/tmp/buysell-submit-readiness-export-preflight.log`, App Store validation blocker log `/tmp/buysell-submit-readiness-app-store-validation-preflight.log`, real-device blocker log `/tmp/buysell-submit-readiness-real-device-preflight.log`, real-device acceptance evidence blocker log `/tmp/buysell-submit-readiness-acceptance-evidence.log`, secret-scan log `/tmp/buysell-submit-readiness-secret-scan.log`, combined readiness blocker log `/tmp/buysell-submit-readiness-combined.log`.

## Commands

Run the full simulator suite:

```sh
xcodebuild test \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1
```

Run the no-sign Release archive package check:

```sh
bash Scripts/verify_m10_local_archive.sh /tmp/BuySellAI-nosign.xcarchive
```

Run the signed archive preflight after selecting a real Apple development team:

```sh
bash Scripts/preflight_m10_signed_archive.sh /tmp/BuySellAI-signed.xcarchive
```

Run the App Store Connect export preflight after selecting a real Apple development team:

```sh
bash Scripts/preflight_m10_app_store_export.sh /tmp/BuySellAI-appstore.xcarchive /tmp/BuySellAI-appstore-export
```

Run the App Store Connect validation preflight after exporting an IPA and configuring API-key credentials:

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

The default signed and App Store export preflights should pass without `ALLOW_MISSING_TEAM=1`, and the App Store validation preflight should pass without `ALLOW_MISSING_ASC=1`, before checking the signed archive gates below.

Run the real-device preflight after connecting a trusted iPhone or iPad with Developer Mode enabled:

```sh
bash Scripts/preflight_m10_real_device.sh
```

To target a specific connected device:

```sh
DEVICE_ID=<devicectl-identifier> bash Scripts/preflight_m10_real_device.sh
```

Until a trusted physical device is connected, record the known blocker:

```sh
ALLOW_MISSING_DEVICE=1 bash Scripts/preflight_m10_real_device.sh
```

Run the real-device manual acceptance evidence check after completing the device pass:

```sh
bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Until the physical-device QA pass is complete, record the known blocker:

```sh
ALLOW_PENDING_ACCEPTANCE=1 bash Scripts/verify_m10_real_device_acceptance.sh M10_ACCEPTANCE.md
```

Run the secret-pattern scan:

```sh
bash Scripts/scan_m10_secrets.sh
```

The scan should print `M10 secret scan passed`.

Run the combined M10 submit-readiness gate after producing every evidence artifact above:

```sh
bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

Until the signed archive, App Store, real-device, and manual evidence gates are complete, record the known blockers:

```sh
ALLOW_PENDING_M10=1 bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

## Submit-Ready Gates

- [ ] Configure a real Apple development team for the app target.
- [ ] Produce a signed Release archive with automatic signing enabled.
- [ ] Export an App Store Connect IPA with automatic signing enabled.
- [ ] Validate the signed archive in Xcode Organizer.
- [ ] Validate the exported IPA with App Store Connect API-key credentials.
- [ ] Confirm Sign in with Apple entitlement is present in the signed archive.
- [ ] Confirm App Store privacy manifest validation passes.
- [ ] Run the real-device preflight on a trusted physical iPhone or iPad.
- [ ] Record a passing 15-item real-device acceptance evidence table.
- [ ] Run the combined M10 submit-readiness gate without `ALLOW_PENDING_M10=1`.

## Real-Device Acceptance

Record the metadata before checking the items. Run `Scripts/preflight_m10_real_device.sh` first so the app has a Release build path for the same trusted device, then update every Result to `Pass` and replace every `TBD` evidence note.

| Field | Value |
| --- | --- |
| Device model | TBD |
| iOS version | TBD |
| Backend project | TBD |
| Tester | TBD |
| Date | TBD |
| Release build | TBD |
| Signed archive | TBD |
| App Store validation | TBD |

| ID | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| A01 | Cold launch reaches Home in under 1 second with no flicker. | Pending | TBD |
| A02 | Tapping `Snap to sell` opens a live camera preview within 400 ms. | Pending | TBD |
| A03 | Shutter capture presents the result sheet within 300 ms and includes a valid thumbnail. | Pending | TBD |
| A04 | Analyze returns a name and price for a common household item. | Pending | TBD |
| A05 | Marketplace picker shows the same platforms as §8.5 with plausible payouts and correct Best/Lowest badges. | Pending | TBD |
| A06 | Copy places only listing text on the clipboard, with no leading whitespace or generated preamble. | Pending | TBD |
| A07 | Recent listing appears on Home immediately after copy and includes a working thumbnail. | Pending | TBD |
| A08 | Swipe-to-delete removes the listing and fires warning haptic feedback. | Pending | TBD |
| A09 | Kill and re-open the app -> history persists (guest via SwiftData; signed-in via server). | Pending | TBD |
| A10 | Reduce Motion in Settings reduces app-wide animation. | Pending | TBD |
| A11 | Dark mode keeps every screen readable with acceptable contrast. | Pending | TBD |
| A12 | iPhone landscape rotation keeps the app portrait and stable. | Pending | TBD |
| A13 | VoiceOver can complete Home -> Camera -> Result -> Picker -> Listing -> Copy without ambiguity. | Pending | TBD |
| A14 | Airplane mode allows capture, then analyze fails with `You're offline. Reconnect and try again.` plus retry. | Pending | TBD |
| A15 | Sign in with Apple migrates guest history once without duplicates. | Pending | TBD |

## Result Log

Use one row per real-device pass.

| Date | Tester | Device | iOS | Backend | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | TBD | TBD | Pending | Signed archive and real-device QA not yet complete. |
