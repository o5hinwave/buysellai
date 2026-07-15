# M10 Acceptance Checklist

This checklist tracks the remaining submit-readiness work for BuySell AI iOS. Simulator tests and no-sign archives are useful evidence, but v1 is not complete until the signed archive and real-device checks below are recorded.

## Current Evidence

- Simulator suite: `254` unit/UI tests pass on iPhone 16 Pro simulator, iOS 18.6.
- No-sign Release iPhoneOS archive: compiles and packages a `3.1M` app bundle.
- Package checks: `PrivacyInfo.xcprivacy` is present, camera permission metadata is present, photo-library permission metadata is absent.
- Secret scan: no Gemini/OpenAI-style provider secret patterns are present in app or test sources.
- Latest local evidence: focused contrast-token result bundle `/tmp/buysell-contrast-tokens.xcresult`, full-suite result bundle `/tmp/buysell-full-contrast-tokens.xcresult`, no-sign archive `/tmp/buysell-contrast-tokens.xcarchive`.

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
xcodebuild archive \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/BuySellAI-nosign.xcarchive \
  CODE_SIGNING_ALLOWED=NO
```

Run the secret-pattern scan:

```sh
rg -l -I 'AQ\.[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}' \
  BuySellAI BuySellAITests BuySellAIUITests README.md M10_ACCEPTANCE.md
```

The scan should return no filenames.

## Submit-Ready Gates

- [ ] Configure a real Apple development team for the app target.
- [ ] Produce a signed Release archive with automatic signing enabled.
- [ ] Validate the signed archive in Xcode Organizer.
- [ ] Confirm Sign in with Apple entitlement is present in the signed archive.
- [ ] Confirm App Store privacy manifest validation passes.

## Real-Device Acceptance

Record the device model, iOS version, backend project, tester, and date before checking these items.

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
