# M10 Acceptance Checklist

This checklist tracks the remaining submit-readiness work for BuySell AI iOS. Simulator tests and no-sign archives are useful evidence, but v1 is not complete until the signed archive and real-device checks below are recorded.

## Current Evidence

- Simulator suite: `326` unit/UI tests pass on iPhone 16 Pro simulator, iOS 18.6.
- No-sign Release iPhoneOS archive: compiles and packages a `3208KB` app bundle.
- Binary-size check: archived app bundle stays under `20 MB`.
- App icon check: source App Store icon is a 1024x1024 non-alpha PNG and the archive contains iPhone/iPad icon PNGs.
- Package checks: `PrivacyInfo.xcprivacy` is present. Privacy manifest content check passes for no tracking, app-functionality data use, and UserDefaults required-reason metadata. Camera permission metadata is present, and photo-library permission metadata is absent.
- Secret scan: the scanner self-test passes and no Gemini/OpenAI-style provider secret patterns are present in repo text files outside generated bundles.
- Simulator performance evidence: launch, camera-ready, capture-to-result thumbnail, slow history load, and 500-row history scroll UI tests pass in the full suite; `Scripts/verify_m10_performance_evidence.sh` passed with 5 performance tests and a `3208KB / 20480KB` app-size result.
- App Store screenshot evidence: four 1206 x 2622 iPhone 16 Pro simulator PNGs are retained in `AppStoreAssets/Screenshots/iPhone-16-Pro/`, captured by `BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured` in the current submit-readiness full-suite result bundle `/tmp/buysell-submit-readiness-full.xcresult`; the earlier standalone capture bundle `/tmp/buysell-m10-screenshots.xcresult` is also retained.
- Latest local evidence: focused submit-readiness preflight result bundle `/tmp/buysell-submit-readiness-focused.xcresult`, full-suite result bundle `/tmp/buysell-submit-readiness-full.xcresult`, no-sign archive `/tmp/buysell-submit-readiness-nosign.xcarchive`, verifier log `/tmp/buysell-submit-readiness-nosign.log`, signed-preflight blocker log `/tmp/buysell-submit-readiness-signed-preflight.log`, App Store export blocker log `/tmp/buysell-submit-readiness-export-preflight.log`, App Store validation blocker log `/tmp/buysell-submit-readiness-app-store-validation-preflight.log`, App Store metadata evidence log `/tmp/buysell-submit-readiness-app-store-metadata.log`, backend blocker log `/tmp/buysell-submit-readiness-backend.log`, real-device blocker log `/tmp/buysell-submit-readiness-real-device-preflight.log`, real-device acceptance evidence blocker log `/tmp/buysell-submit-readiness-acceptance-evidence.log`, secret-scan log `/tmp/buysell-submit-readiness-secret-scan.log`, performance evidence log `/tmp/buysell-submit-readiness-performance.log`, Instruments evidence blocker log `/tmp/buysell-submit-readiness-instruments.log`, combined readiness blocker log `/tmp/buysell-submit-readiness-combined.log`.

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
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_signed_archive.sh /tmp/BuySellAI-signed.xcarchive
```

Run the App Store Connect export preflight after selecting a real Apple development team:

```sh
M10_DEVELOPMENT_TEAM=<team-id> \
bash Scripts/preflight_m10_app_store_export.sh /tmp/BuySellAI-appstore.xcarchive /tmp/BuySellAI-appstore-export
```

Run the App Store Connect validation preflight after exporting an IPA and configuring API-key credentials:

```sh
ASC_API_KEY_ID=<key-id> \
ASC_API_ISSUER_ID=<issuer-id> \
ASC_API_PRIVATE_KEYS_DIR=<directory-containing-AuthKey_key-id.p8> \
bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export
```

`M10_DEVELOPMENT_TEAM` lets the release preflights use a personal Apple Team ID without committing it to the Xcode project. Selecting the team in Xcode is also valid.

Until the Apple team, exported IPA, and App Store Connect API-key credentials are available, record the known blockers:

```sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_signed_archive.sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_app_store_export.sh
ALLOW_MISSING_ASC=1 bash Scripts/preflight_m10_app_store_validate.sh /tmp/BuySellAI-appstore-export
```

The default signed and App Store export preflights should pass without `ALLOW_MISSING_TEAM=1`, and the App Store validation preflight should pass without `ALLOW_MISSING_ASC=1`, before checking the signed archive gates below.

Run the App Store Connect metadata evidence verifier after product-page metadata, screenshots, public unauthenticated privacy/support URLs, app privacy answers, age rating, DSA status, and review notes are recorded:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

Passing logs include `file:`, `app name:`, `bundle id:`, `version:`, `privacy policy:`, `support:`, `screenshots:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot result bundle:`, `screenshot capture test:`, and `app privacy:` markers. The verifier also confirms the retained PNG screenshot files exist, match the expected `1206x2622` iPhone 16 Pro dimensions, and came from a retained xcresult where `testM10AppStoreScreenshotsCanBeCaptured()` passed. Until those App Store Connect fields are complete, record the known blocker:

```sh
ALLOW_PENDING_METADATA=1 bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

The App Store support/privacy site source is in `AppStoreSite/`. Sites version 3 is saved from commit `2cbaf9521ecb2848d4ef9c321670dc8968055f34` and deployed at `https://buysell-ai-support.o5hinwavve.chatgpt.site`; site access was changed to public on 2026-07-16, and unauthenticated support, privacy, and terms requests return `200`. The metadata verifier checks that filled-in Support URL and Privacy Policy URL values are public HTTPS pages reachable without authentication. App Store screenshot evidence is retained in `AppStoreAssets/Screenshots/iPhone-16-Pro/`.

Run the M10 backend smoke preflight after `Config.plist`, the deployed Edge Functions, and a retained JPEG sample are available:

```sh
M10_ANALYZE_IMAGE_JPEG=/path/to/common-item.jpg \
bash Scripts/preflight_m10_backend.sh BuySellAI/App/Config.plist
```

The backend preflight reads only the public Supabase URL and anon key from `Config.plist`; it does not print the anon key or any AI provider secret. The app and preflight both reject copied `Config.plist.example` placeholders before making backend requests. Passing logs include `config:`, `project:`, `functions: analyze-image generate-listing`, `analyze item:`, and `listing bytes:` markers.

Until the real Supabase config and sample image are available, record the known blocker:

```sh
ALLOW_MISSING_BACKEND=1 bash Scripts/preflight_m10_backend.sh
```

Run the real-device preflight after connecting a trusted iPhone or iPad with Developer Mode enabled:

```sh
M10_DEVELOPMENT_TEAM=<team-id> bash Scripts/preflight_m10_real_device.sh
```

To target a specific connected device:

```sh
M10_DEVELOPMENT_TEAM=<team-id> DEVICE_ID=<devicectl-identifier> bash Scripts/preflight_m10_real_device.sh
```

The preflight ignores non-iOS `devicectl` entries. A supplied `DEVICE_ID` must match a connected iPhone or iPad.

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

The scan should print both `M10 secret scan self-test passed` and `M10 secret scan passed`.

Run the M10 performance evidence verifier after the full simulator suite and no-sign archive verifier finish:

```sh
bash Scripts/verify_m10_performance_evidence.sh \
  /tmp/buysell-submit-readiness-full.xcresult \
  /tmp/buysell-submit-readiness-nosign.log
```

The performance evidence verifier checks the full-suite result, named simulator performance UI tests, the archived app-size budget, and carries forward the no-sign archive `bundle id:` and `release build:` markers. It does not replace the final physical-device timing checks in the real-device acceptance table.

Run the M10 Instruments evidence verifier after profiling a signed Release build on a trusted physical device with Time Profiler and Allocations:

```sh
bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

Until the signed physical-device Instruments pass is complete, record the known blocker:

```sh
ALLOW_PENDING_INSTRUMENTS=1 bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

The Instruments evidence verifier checks the final hardware timing, scroll, memory, and trace-retention evidence in `M10_INSTRUMENTS.md`.

Run the combined M10 submit-readiness gate after producing every evidence artifact above:

```sh
bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

The combined gate checks that pass logs retain their concrete artifact markers: no-sign `archive:`, `bundle id:`, `release build:`, and `app size:`, signed `archive:`, `bundle id:`, `sign in with apple:`, and `release build:`, App Store export `archive:`, `export:`, `ipa:`, `bundle id:`, `sign in with apple:`, and `release build:`, App Store validation `ipa:`, `bundle id:`, `sign in with apple:`, and `release build:`, App Store metadata `app name:`, `bundle id:`, `privacy policy:`, `support:`, `screenshots:`, `screenshot directory:`, `screenshot files:`, `screenshot dimensions:`, `screenshot result bundle:`, `screenshot capture test:`, and `app privacy:`, backend `config:`, `project:`, `functions:`, `analyze item:`, and `listing bytes:`, real-device `device:`, `device name:`, `device id:`, `app:`, `bundle id:`, `sign in with apple:`, and `release build:`, secret scan `M10 secret scan self-test passed` and `M10 secret scan passed`, performance `full suite:`, `archive log:`, `bundle id:`, `release build:`, `performance tests:`, `performance test:`, and `app size:`, and Instruments `file:`. It also confirms the local simulator result bundles, no-sign archive, no-sign verifier log, secret-scan log, and performance evidence log are fresh for the current HEAD commit; passing signed/App Store/backend/real-device/Instruments artifacts must be fresh too. It confirms the App Store validation log references the same `ipa:` path produced by the export preflight, the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `bundle id:` marker, the signed archive, App Store export, App Store validation, and real-device preflight logs retain the same `sign in with apple:` entitlement marker, the no-sign archive, signed archive, App Store export, App Store validation, and real-device preflight logs record the same `release build:` value, the performance evidence log retains the same no-sign archive `bundle id:` and `release build:` values plus every required simulator budget test name, the acceptance `Signed archive` metadata references the signed-preflight `archive:` path, the acceptance `Signed archive validation` metadata mentions Xcode Organizer validation proof and references the signed-preflight `archive:` path, the acceptance `App Store validation` metadata references the validated `ipa:` path, the acceptance and Instruments `Release build` metadata match the signed-preflight `release build:` value, the acceptance and Instruments `Device model` metadata reference the real-device preflight `device name:` value, the Instruments `Signed archive` metadata references the same signed-preflight `archive:` path, and the acceptance and Instruments `iOS version` and `Release build` metadata match for the same physical-device pass. If your retained artifacts use non-default paths, set `M10_NOSIGN_ARCHIVE`, `M10_SIGNED_ARCHIVE`, `M10_APP_STORE_ARCHIVE`, `M10_APP_STORE_EXPORT`, `M10_APP_STORE_METADATA`, `M10_APP_STORE_METADATA_LOG`, `M10_BACKEND_LOG`, and `M10_INSTRUMENTS_EVIDENCE` before running this gate.

Until the signed archive, App Store metadata/submission, backend, real-device, and manual evidence gates are complete, record the known blockers:

```sh
ALLOW_PENDING_M10=1 bash Scripts/verify_m10_submit_readiness.sh M10_ACCEPTANCE.md
```

## Submit-Ready Gates

- [ ] Configure a real Apple development team for the app target.
- [ ] Produce a signed Release archive with automatic signing enabled.
- [ ] Export an App Store Connect IPA with automatic signing enabled.
- [ ] Validate the signed archive in Xcode Organizer.
- [ ] Validate the exported IPA with App Store Connect API-key credentials.
- [ ] Complete App Store Connect metadata, screenshots, public privacy/support URLs, app privacy answers, age rating, DSA status, and legal owner fields.
- [ ] Run the M10 backend smoke preflight against the production Supabase project.
- [ ] Confirm Sign in with Apple entitlement is present in the signed archive.
- [x] Confirm App Store privacy manifest validation passes.
- [ ] Run the real-device preflight on a trusted physical iPhone or iPad.
- [ ] Record a passing 15-item real-device acceptance evidence table.
- [x] Run the M10 performance evidence verifier.
- [ ] Run the M10 Instruments evidence verifier.
- [ ] Run the combined M10 submit-readiness gate without `ALLOW_PENDING_M10=1`.

## Real-Device Acceptance

Record the metadata before checking the items. Run `Scripts/preflight_m10_real_device.sh` first so the app has a Release build path for the same trusted device, then update every Result to `Pass` and replace every `TBD` evidence note. Metadata is validated too: `Date` must use `YYYY-MM-DD`, `Device model` must mention iPhone or iPad and include the real-device preflight `device name:` value, `iOS version` and `Release build` must include numeric values, `Release build` must match the signed-preflight `release build:` marker before final submit-readiness, `Signed archive` must mention an archive and include the signed-preflight `archive:` path, `Signed archive validation` must mention Xcode Organizer validation proof and include the signed-preflight `archive:` path, and `App Store validation` must mention validation, validated, altool, App Store, or IPA proof and include the validated `ipa:` path. For A01-A03, include the measured duration in `ms` or seconds in the Evidence cell so the verifier can enforce the launch, camera-ready, and capture-to-result budgets.

Every Evidence cell must cite the observed proof, not only say "passed". The verifier checks for these proof terms: A01 `home`, `no flicker`; A02 `camera`, `preview`; A03 `result sheet`, `thumbnail`; A04 `item`, `price`; A05 `platform`, `payout`, `best`, `lowest`, `27`, `ebay`, `craigslist`, `facebook`, `poshmark`, `mercari`, `offerup`, `depop`, `whatnot`, `grailed`, `reverb`, `etsy`, `stockx`, `goat`, `kidizen`, `vinted`, `vestiaire`, `the realreal`, `swappa`, `tradesy`, `chairish`, `bonanza`, `curtsy`, `nextdoor`, `amazon`, `shopify`, `ruby lane`, `tcgplayer`; A06 `clipboard`, `listing text`, `no leading whitespace`, `no preamble`; A07 `home`, `thumbnail`; A08 `swipe`, `haptic`; A09 `relaunch`, `guest`, `swiftdata`, `signed`, `server`; A10 `settings`, `reduce motion`, `animation`, `app-wide`; A11 `dark`, `contrast`; A12 `landscape`, `portrait`; A13 `voiceover`, `home`, `camera`, `result`, `picker`, `listing`, `copy`; A14 `airplane`, `offline`, `you're offline. reconnect and try again.`, `retry`; A15 `sign in with apple`, `migration`, `once`, `duplicate`.

| Field | Value |
| --- | --- |
| Device model | TBD |
| iOS version | TBD |
| Backend project | TBD |
| Tester | TBD |
| Date | TBD |
| Release build | TBD |
| Signed archive | TBD |
| Signed archive validation | TBD |
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

Before the combined submit-readiness gate can pass, replace the placeholder row with at least one complete row from the final signed physical-device QA pass. Every field must be concrete, `Result` must be `Pass`, the row must match the recorded Date, Tester, Device model, iOS version, and Backend project metadata, and `Notes` must mention the signed archive, Xcode Organizer signed archive validation, App Store validation, real-device acceptance, and Instruments evidence used for that pass.

| Date | Tester | Device | iOS | Backend | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | TBD | TBD | Pending | Signed archive and real-device QA not yet complete. |
