# M10 Acceptance Checklist

This checklist tracks the remaining submit-readiness work for BuySell AI iOS. Simulator tests and no-sign archives are useful evidence, but v1 is not complete until the signed archive and real-device checks below are recorded.

## Current Evidence

- Simulator suite: `296` unit/UI tests pass on iPhone 16 Pro simulator, iOS 18.6.
- No-sign Release iPhoneOS archive: compiles and packages a `3188KB` app bundle.
- Binary-size check: archived app bundle stays under `20 MB`.
- Package checks: `PrivacyInfo.xcprivacy` is present, camera permission metadata is present, photo-library permission metadata is absent.
- Secret scan: no Gemini/OpenAI-style provider secret patterns are present in repo text files outside generated bundles.
- Simulator performance evidence: launch, camera-ready, capture-to-result thumbnail, slow history load, and 500-row history scroll UI tests pass in the full suite; `Scripts/verify_m10_performance_evidence.sh` passed with 5 performance tests and a `3188KB / 20480KB` app-size result.
- Latest local evidence: focused submit-readiness preflight result bundle `/tmp/buysell-submit-readiness-focused.xcresult`, full-suite result bundle `/tmp/buysell-submit-readiness-full.xcresult`, no-sign archive `/tmp/buysell-submit-readiness-nosign.xcarchive`, verifier log `/tmp/buysell-submit-readiness-nosign.log`, signed-preflight blocker log `/tmp/buysell-submit-readiness-signed-preflight.log`, App Store export blocker log `/tmp/buysell-submit-readiness-export-preflight.log`, App Store validation blocker log `/tmp/buysell-submit-readiness-app-store-validation-preflight.log`, real-device blocker log `/tmp/buysell-submit-readiness-real-device-preflight.log`, real-device acceptance evidence blocker log `/tmp/buysell-submit-readiness-acceptance-evidence.log`, secret-scan log `/tmp/buysell-submit-readiness-secret-scan.log`, performance evidence log `/tmp/buysell-submit-readiness-performance.log`, Instruments evidence blocker log `/tmp/buysell-submit-readiness-instruments.log`, combined readiness blocker log `/tmp/buysell-submit-readiness-combined.log`.

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

The scan should print `M10 secret scan passed`.

Run the M10 performance evidence verifier after the full simulator suite and no-sign archive verifier finish:

```sh
bash Scripts/verify_m10_performance_evidence.sh \
  /tmp/buysell-submit-readiness-full.xcresult \
  /tmp/buysell-submit-readiness-nosign.log
```

The performance evidence verifier checks the full-suite result, named simulator performance UI tests, and the archived app-size budget. It does not replace the final physical-device timing checks in the real-device acceptance table.

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

The combined gate checks that pass logs retain their concrete artifact markers: no-sign `archive:` and `app size:`, signed `archive:`, App Store export `archive:`, `export:`, and `ipa:`, App Store validation `ipa:`, real-device `device:`, performance `full suite:`, `archive log:`, `performance tests:`, and `app size:`, and Instruments `file:`. It also confirms the App Store validation log references the same `ipa:` path produced by the export preflight, the acceptance `Signed archive` metadata references the signed-preflight `archive:` path, the acceptance `App Store validation` metadata references the validated `ipa:` path, and the Instruments `Signed archive` metadata references the same signed-preflight `archive:` path. If your retained artifacts use non-default paths, set `M10_NOSIGN_ARCHIVE`, `M10_SIGNED_ARCHIVE`, `M10_APP_STORE_ARCHIVE`, `M10_APP_STORE_EXPORT`, and `M10_INSTRUMENTS_EVIDENCE` before running this gate.

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
- [x] Run the M10 performance evidence verifier.
- [ ] Run the M10 Instruments evidence verifier.
- [ ] Run the combined M10 submit-readiness gate without `ALLOW_PENDING_M10=1`.

## Real-Device Acceptance

Record the metadata before checking the items. Run `Scripts/preflight_m10_real_device.sh` first so the app has a Release build path for the same trusted device, then update every Result to `Pass` and replace every `TBD` evidence note. Metadata is validated too: `Date` must use `YYYY-MM-DD`, `Device model` must mention iPhone or iPad, `iOS version` and `Release build` must include numeric values, `Signed archive` must mention an archive and include the signed-preflight `archive:` path, and `App Store validation` must mention validation, validated, altool, App Store, or IPA proof and include the validated `ipa:` path. For A01-A03, include the measured duration in `ms` or seconds in the Evidence cell so the verifier can enforce the launch, camera-ready, and capture-to-result budgets.

Every Evidence cell must cite the observed proof, not only say "passed". The verifier checks for these proof terms: A01 `home`, `no flicker`; A02 `camera`, `preview`; A03 `result sheet`, `thumbnail`; A04 `item`, `price`; A05 `platform`, `payout`, `best`, `lowest`; A06 `clipboard`, `listing text`, `no leading whitespace`, `no preamble`; A07 `home`, `thumbnail`; A08 `swipe`, `haptic`; A09 `relaunch`, `guest`, `signed`, `server`; A10 `reduce motion`; A11 `dark`, `contrast`; A12 `landscape`, `portrait`; A13 `voiceover`, `home`, `camera`, `result`, `picker`, `listing`, `copy`; A14 `airplane`, `offline`, `you're offline. reconnect and try again.`, `retry`; A15 `sign in with apple`, `migration`, `once`, `duplicate`.

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

Before the combined submit-readiness gate can pass, replace the placeholder row with at least one complete row from the final signed physical-device QA pass. Every field must be concrete, `Result` must be `Pass`, and `Notes` must mention the signed archive, App Store validation, real-device acceptance, and Instruments evidence used for that pass.

| Date | Tester | Device | iOS | Backend | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | TBD | TBD | Pending | Signed archive and real-device QA not yet complete. |
