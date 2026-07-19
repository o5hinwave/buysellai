# App Store Screenshot Evidence

These PNGs are simulator-captured evidence for the App Store Connect screenshot set. The metadata verifier requires both the retained PNGs and a retained xcresult proving the screenshot capture UI test passed.

## iPhone 16 Pro Max

| File | Screen |
| --- | --- |
| `iPhone-16-Pro-Max/01-home.png` | Home |
| `iPhone-16-Pro-Max/02-result.png` | Analyzed item result |
| `iPhone-16-Pro-Max/03-marketplaces.png` | Marketplace picker |
| `iPhone-16-Pro-Max/04-listing.png` | Generated listing |

- Device: iPhone 16 Pro Max simulator
- iOS: 18.6
- PNG dimensions: 1320 x 2868
- Result bundle: `/tmp/buysell-m10-screenshots-iphone-16-pro-max.xcresult`
- Capture test: `BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured`

## iPad Pro 13-inch (M4)

| File | Screen |
| --- | --- |
| `iPad-Pro-13-inch-M4/01-home.png` | Home |
| `iPad-Pro-13-inch-M4/02-result.png` | Analyzed item result |
| `iPad-Pro-13-inch-M4/03-marketplaces.png` | Marketplace picker |
| `iPad-Pro-13-inch-M4/04-listing.png` | Generated listing |

- Device: iPad Pro 13-inch (M4) simulator
- iOS: 18.6
- PNG dimensions: 2064 x 2752
- Result bundle: `/tmp/buysell-m10-screenshots-ipad-pro-13.xcresult`
- Capture test: `BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured`

Verify the retained files and App Store metadata evidence with:

```sh
bash Scripts/verify_m10_app_store_metadata.sh M10_APP_STORE_METADATA.md
```

Regenerate the required iPhone 6.9-inch set from a booted iPhone 16 Pro Max simulator by deleting the existing PNGs under `iPhone-16-Pro-Max/`, then running:

```sh
xcodebuild test \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -destination 'id=D4D2F3E7-CDCD-4015-B946-D34FF5204805' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured \
  -resultBundlePath /tmp/buysell-m10-screenshots-iphone-16-pro-max.xcresult
```

Regenerate the required iPad 13-inch set from a booted iPad Pro 13-inch (M4) simulator by deleting the existing PNGs under `iPad-Pro-13-inch-M4/`, then running:

```sh
xcodebuild test \
  -project BuySellAI.xcodeproj \
  -scheme BuySellAI \
  -destination 'id=1E941C0E-294A-4CDD-961F-A52FF66D28EA' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:BuySellAIUITests/BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured \
  -resultBundlePath /tmp/buysell-m10-screenshots-ipad-pro-13.xcresult
```

The retained iPhone 6.9-inch and iPad 13-inch sets match the required App Store Connect display classes for a universal iPhone/iPad app. The broader simulator suite is retained separately at `/tmp/buysell-submit-readiness-full.xcresult`.
