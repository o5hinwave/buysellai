# App Store Screenshot Evidence

These PNGs are simulator-captured evidence for the App Store Connect screenshot set.

## iPhone 16 Pro

| File | Screen |
| --- | --- |
| `iPhone-16-Pro/01-home.png` | Home |
| `iPhone-16-Pro/02-result.png` | Analyzed item result |
| `iPhone-16-Pro/03-marketplaces.png` | Marketplace picker |
| `iPhone-16-Pro/04-listing.png` | Generated listing |

- Device: iPhone 16 Pro simulator
- iOS: 18.6
- PNG dimensions: 1206 x 2622
- Result bundle: `/tmp/buysell-m10-screenshots.xcresult`
- Capture test: `BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured`

Regenerate from a booted iPhone 16 Pro simulator by deleting the existing PNGs under `iPhone-16-Pro/`, then running:

```sh
xcodebuild test \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -destination 'id=060AA83C-A1A5-4233-ACF5-E015E088FB46' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured \
  -resultBundlePath /tmp/buysell-m10-screenshots.xcresult
```

The initial iPhone 16 Pro Max simulator run was flaky before app launch; the retained evidence above is from the stable iPhone 16 Pro simulator pass. Repeat this capture on any additional display sizes required by App Store Connect before final upload.
