# M10 Acceptance Checklist

This checklist tracks the remaining submit-readiness work for BuySell AI iOS. Simulator tests and no-sign archives are useful evidence, but v1 is not complete until the signed archive and real-device checks below are recorded.

## Current Evidence

- Simulator suite: `272` unit/UI tests pass on iPhone 16 Pro simulator, iOS 18.6.
- No-sign Release iPhoneOS archive: compiles and packages a `3.1M` app bundle.
- Binary-size check: archived app bundle stays under `20 MB`.
- Package checks: `PrivacyInfo.xcprivacy` is present, camera permission metadata is present, photo-library permission metadata is absent.
- Secret scan: no Gemini/OpenAI-style provider secret patterns are present in repo text files outside generated bundles.
- Latest local evidence: focused App Store export preflight result bundle `/tmp/buysell-app-store-export-preflight.xcresult`, full-suite result bundle `/tmp/buysell-full-app-store-export-preflight.xcresult`, no-sign archive `/tmp/buysell-app-store-export-nosign.xcarchive`, verifier log `/tmp/buysell-app-store-export-nosign.log`, signed-preflight blocker log `/tmp/buysell-app-store-export-signed-preflight.log`, App Store export blocker log `/tmp/buysell-app-store-export-preflight.log`, real-device blocker log `/tmp/buysell-app-store-export-real-device-preflight.log`, secret-scan log `/tmp/buysell-app-store-export-secret-scan.log`.

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

Until the team is configured, record the known blocker:

```sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_signed_archive.sh
ALLOW_MISSING_TEAM=1 bash Scripts/preflight_m10_app_store_export.sh
```

The default signed and App Store export preflights should pass without `ALLOW_MISSING_TEAM=1` before checking the signed archive gates below.

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

Run the secret-pattern scan:

```sh
bash Scripts/scan_m10_secrets.sh
```

The scan should print `M10 secret scan passed`.

## Submit-Ready Gates

- [ ] Configure a real Apple development team for the app target.
- [ ] Produce a signed Release archive with automatic signing enabled.
- [ ] Export an App Store Connect IPA with automatic signing enabled.
- [ ] Validate the signed archive in Xcode Organizer.
- [ ] Confirm Sign in with Apple entitlement is present in the signed archive.
- [ ] Confirm App Store privacy manifest validation passes.
- [ ] Run the real-device preflight on a trusted physical iPhone or iPad.

## Real-Device Acceptance

Record the device model, iOS version, backend project, tester, and date before checking these items. Run `Scripts/preflight_m10_real_device.sh` first so the app has a Release build path for the same trusted device.

- [ ] Cold launch reaches Home in under 1 second with no flicker.
- [ ] Tapping `Snap to sell` opens a live camera preview within 400 ms.
- [ ] Shutter capture presents the result sheet within 300 ms and includes a valid thumbnail.
- [ ] Analyze returns a name and price for a common household item.
- [ ] Marketplace picker shows the full platform list with plausible payouts and correct Best/Lowest badges.
- [ ] Copy places only listing text on the clipboard, with no leading whitespace or preamble.
- [ ] Recent listing appears on Home immediately after copy and includes a working thumbnail.
- [ ] Swipe-to-delete removes the listing and fires warning haptic feedback.
- [ ] Guest history persists after killing and reopening the app.
- [ ] Signed-in history sync persists after killing and reopening the app.
- [ ] Reduce Motion in Settings reduces app-wide animation.
- [ ] Dark mode keeps every screen readable with acceptable contrast.
- [ ] iPhone landscape rotation keeps the app portrait and stable.
- [ ] VoiceOver can complete Home to Camera to Result to Picker to Listing to Copy without ambiguity.
- [ ] Airplane mode allows capture, then analyze fails with `You're offline. Reconnect and try again.` plus retry.
- [ ] Sign in with Apple migrates guest history once without duplicates.

## Result Log

Use one row per real-device pass.

| Date | Tester | Device | iOS | Backend | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | TBD | TBD | Pending | Signed archive and real-device QA not yet complete. |
