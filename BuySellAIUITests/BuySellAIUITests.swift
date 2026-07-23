import UIKit
import XCTest

final class BuySellAIUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTutorialCanBeSkippedAndHappyPathCopiesListingWithUITestHooks() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
        }

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("craigslist", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: copy)
        waitForExpectations(timeout: 5)
        copy.tap()

        let toast = app.descendants(matching: .any)["Toast"]
        let recentListing = app.staticTexts["Vintage brass table lamp"]
        XCTAssertTrue(toast.waitForExistence(timeout: 2) || recentListing.waitForExistence(timeout: 5))
    }

    func testFirstLaunchTutorialAppearsOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-tutorial"]
        app.launch()

        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        skip.tap()
        app.terminate()

        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertFalse(app.buttons["Skip"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
    }

    func testSlowHistoryLoadDoesNotBlockHomeLaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--reset-auth",
            "--reset-history",
            "--ui-testing-slow-history-load"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 2))
    }

    func testHomeLaunchReachesPrimaryActionWithinSimulatorBudget() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-preferences", "--reset-auth", "--reset-history"]

        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let startedAt = Date()
        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 6))
        XCTAssertLessThan(
            Date().timeIntervalSince(startedAt),
            6,
            "Home primary action should be reachable within the simulator QA budget; physical launch timing remains a device QA gate."
        )
    }

    func testHomeHandlesFiveHundredRecentListingsAndScrolls() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth", "--seed-large-history"]
        app.launch()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))

        let newest = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Large history item 500")).firstMatch
        XCTAssertTrue(newest.waitForExistence(timeout: 5))

        let deeperRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Large history item 475")).firstMatch
        var attempts = 0
        while deeperRow.exists == false && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(deeperRow.exists)
    }

    func testIPhonePortraitLockKeepsHomeUsableAfterLandscapeRotation() {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial"]
        app.launch()

        defer {
            XCUIDevice.shared.orientation = .portrait
        }

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))

        let portraitFrame = app.windows.element(boundBy: 0).frame
        XCTAssertGreaterThan(portraitFrame.height, portraitFrame.width)

        XCUIDevice.shared.orientation = .landscapeLeft

        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        XCTAssertTrue(snap.isHittable)

        let rotatedFrame = app.windows.element(boundBy: 0).frame
        XCTAssertGreaterThan(rotatedFrame.height, rotatedFrame.width)
    }

    func testAccessibilityThreeHomeKeepsPrimaryActionReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--reset-auth",
            "-UIPreferredContentSizeCategoryName",
            UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Sell anything in three taps."].waitForExistence(timeout: 5))

        let snap = app.buttons["Snap to sell"]
        var attempts = 0
        while snap.isHittable == false && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(snap.exists)
        XCTAssertTrue(snap.isHittable)
    }

    func testConciseTutorialStartSellingDismisses() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-tutorial"]
        app.launch()

        let startSelling = app.buttons["Start selling"]
        XCTAssertTrue(startSelling.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sell anything in three taps."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Take a photo. We suggest where to sell and write the listing."].exists)
        XCTAssertTrue(app.staticTexts["Take a clear photo"].exists)
        XCTAssertTrue(app.staticTexts["Choose where to sell"].exists)
        XCTAssertTrue(app.staticTexts["Copy the listing"].exists)

        startSelling.tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start selling"].exists)
    }

    func testConciseTutorialCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-tutorial"]
        app.launch()

        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start selling"].exists)
        skip.tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start selling"].exists)
    }

    func testHomeHowItWorksReopensTutorial() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial"]
        app.launch()

        let howItWorks = app.buttons["How it works"]
        XCTAssertTrue(howItWorks.waitForExistence(timeout: 5))
        howItWorks.tap()

        XCTAssertTrue(app.buttons["Start selling"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Take a photo. We suggest where to sell and write the listing."].exists)
        XCTAssertFalse(app.buttons["Next"].exists)
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
    }

    func testSettingsReopensHowItWorksTutorial() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial"]
        app.launch()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let howItWorks = app.buttons["Settings.HowItWorks"]
        XCTAssertTrue(howItWorks.waitForExistence(timeout: 5))
        howItWorks.tap()

        XCTAssertTrue(app.buttons["Start selling"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Take a photo. We suggest where to sell and write the listing."].exists)
        XCTAssertFalse(app.buttons["Next"].exists)
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
    }

    func testSettingsClearHistoryRequiresConfirmationAndRemovesRows() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--seed-history"]
        app.launch()

        let listing = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Vintage brass table lamp")).firstMatch
        XCTAssertTrue(listing.waitForExistence(timeout: 5))

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let clearHistory = app.buttons["Settings.ClearHistory"]
        XCTAssertTrue(clearHistory.waitForExistence(timeout: 5))
        clearHistory.tap()

        XCTAssertTrue(app.staticTexts["Clear all listing history? This can't be undone."].waitForExistence(timeout: 2))

        let confirmClear = app.buttons["Settings.ConfirmClearHistory"]
        XCTAssertTrue(confirmClear.waitForExistence(timeout: 2))
        confirmClear.tap()

        let toast = app.descendants(matching: .any)["Toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 3))
        XCTAssertEqual(toast.label, "History cleared.")
        XCTAssertFalse(listing.exists)
    }

    func testDeleteAccountRequiresTypedConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth", "--ui-testing-signed-in"]
        app.launch()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let deleteAccount = app.buttons["Settings.DeleteAccount"]
        var attempts = 0
        while deleteAccount.exists == false && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 2))
        deleteAccount.tap()

        let confirmDelete = app.buttons["Settings.ConfirmDeleteAccount"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        XCTAssertFalse(confirmDelete.isEnabled)

        let confirmation = app.textFields["Settings.DeleteAccountConfirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.tap()
        confirmation.typeText("DELETE")

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: confirmDelete)
        waitForExpectations(timeout: 2)
        XCTAssertTrue(confirmDelete.isEnabled)
    }

    func testSwipeDeleteShowsConfirmationAndRemovesHistoryEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--seed-history"]
        app.launch()

        let listing = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Vintage brass table lamp")).firstMatch
        XCTAssertTrue(listing.waitForExistence(timeout: 5))
        listing.swipeLeft()

        let swipeDelete = app.buttons["Delete listing"]
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 2))
        swipeDelete.tap()

        XCTAssertTrue(app.staticTexts["Delete this listing? This can't be undone."].waitForExistence(timeout: 2))
        app.buttons["Delete listing"].tap()

        XCTAssertTrue(listing.waitForNonExistence(timeout: 3))
    }

    func testAnalyzeOfflineShowsToastAndRetryButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--ui-testing-analyze-offline"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let offlineMessage = app.descendants(matching: .any)["You're offline. Reconnect and try again."]
        XCTAssertTrue(offlineMessage.waitForExistence(timeout: 5))
        let toast = app.descendants(matching: .any)["Toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 2))
        XCTAssertEqual(toast.label, "You're offline. Reconnect and try again.")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["You're offline. Reconnect and try again."].exists)
    }

    func testCameraShutterOfflineAnalyzeShowsThumbnailToastAndRetryButton() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--ui-testing-camera-ready",
            "--ui-testing-camera-sample-capture",
            "--ui-testing-analyze-offline"
        ]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let shutter = app.buttons["Take photo"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()

        XCTAssertTrue(app.descendants(matching: .any)["Item photo"].waitForExistence(timeout: 5))
        let offlineMessage = app.descendants(matching: .any)["You're offline. Reconnect and try again."]
        XCTAssertTrue(offlineMessage.waitForExistence(timeout: 5))
        let toast = app.descendants(matching: .any)["Toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 2))
        XCTAssertEqual(toast.label, "You're offline. Reconnect and try again.")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 2))
    }

    func testCameraSampleCapturePresentsResultThumbnailWithinSimulatorBudget() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--ui-testing-camera-ready",
            "--ui-testing-camera-sample-capture"
        ]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let shutter = app.buttons["Take photo"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))

        let startedAt = Date()
        shutter.tap()

        let itemPhoto = app.descendants(matching: .any)["Item photo"]
        XCTAssertTrue(itemPhoto.waitForExistence(timeout: 5))
        XCTAssertLessThan(
            Date().timeIntervalSince(startedAt),
            5,
            "Captured photo should reach the result thumbnail within the simulator QA budget; physical shutter-to-sheet timing remains a device QA gate."
        )
    }

    func testCameraDeniedShowsSettingsFallbackAndCanClose() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--ui-testing-camera-denied"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        XCTAssertTrue(app.staticTexts["Camera access needed to snap items."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.buttons["Choose Photo"].exists)

        let close = app.buttons["Close"]
        XCTAssertTrue(close.exists)
        close.tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
    }

    func testCameraReadyOverlayExposesAccessibleControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--ui-testing-camera-ready"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose Photo"].exists)
        XCTAssertTrue(app.buttons["Close camera"].exists)
        XCTAssertTrue(app.buttons["Turn flash on"].exists)
        XCTAssertTrue(app.staticTexts["Fit the whole item in the frame"].exists)

        app.buttons["Close camera"].tap()
        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
    }

    func testCameraReadyOverlayAppearsWithinSimulatorBudget() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--ui-testing-camera-ready"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))

        let startedAt = Date()
        snap.tap()

        let shutter = app.buttons["Take photo"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fit the whole item in the frame"].exists)
        XCTAssertLessThan(
            Date().timeIntervalSince(startedAt),
            5,
            "Camera controls should appear within the simulator QA budget; physical preview timing remains a device QA gate."
        )
    }

    func testVoiceOverCriticalPathLabelsStayUnambiguousThroughCopy() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--reset-auth",
            "--reset-history",
            "--ui-testing-camera-ready",
            "--ui-testing-camera-sample-capture",
            "--ui-testing-verify-clipboard"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign in"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)

        app.buttons["Snap to sell"].tap()
        XCTAssertTrue(app.buttons["Close camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Take photo"].exists)
        XCTAssertTrue(app.buttons["Turn flash on"].exists)
        XCTAssertTrue(app.staticTexts["Fit the whole item in the frame"].exists)

        app.buttons["Take photo"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Item photo"].waitForExistence(timeout: 5))
        let itemName = app.buttons["Item name"]
        XCTAssertTrue(itemName.waitForExistence(timeout: 5))
        XCTAssertEqual(itemName.value as? String, "Vintage brass table lamp")
        itemName.tap()
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 5))
        if app.toolbars.buttons["Done"].waitForExistence(timeout: 2) {
            app.toolbars.buttons["Done"].tap()
        }
        XCTAssertTrue(app.textFields["Estimated price"].exists)
        XCTAssertTrue(app.buttons["Category, Home"].exists)
        XCTAssertTrue(app.buttons["Condition, Good"].exists)

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        let bestSummary = app.buttons["MarketplaceSummary.bestChance.craigslist"]
        XCTAssertTrue(bestSummary.waitForExistence(timeout: 5))
        XCTAssertTrue(bestSummary.label.contains("Best chance"))
        XCTAssertTrue(bestSummary.label.contains("Craigslist"))
        XCTAssertTrue(bestSummary.label.contains("estimated payout"))

        let craigslistRow = app.buttons["MarketplaceRow.craigslist"]
        XCTAssertTrue(craigslistRow.waitForExistence(timeout: 5))
        XCTAssertTrue(craigslistRow.label.contains("Craigslist"))
        XCTAssertTrue(craigslistRow.label.contains("estimated payout"))
        tapMarketplace("craigslist", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close listing"].exists)
        XCTAssertTrue(app.staticTexts["Generated listing text"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Wrong item — retake"].exists)
        XCTAssertTrue(app.buttons["Regenerate"].exists)

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: copy)
        waitForExpectations(timeout: 5)
        copy.tap()

        XCTAssertTrue(app.staticTexts["Clipboard exact listing text"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Toast"].waitForExistence(timeout: 3))
    }

    func testAuthCanBeDismissedAndGuestSnapStillWorks() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth"]
        app.launch()

        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue with Email"].exists)

        let keepGoing = app.buttons["Keep going without an account"]
        XCTAssertTrue(keepGoing.exists)
        keepGoing.tap()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        XCTAssertTrue(app.buttons["Looks right — pick where to sell"].waitForExistence(timeout: 5))
    }

    func testAuthGuestEscapeRemainsReachableAtAccessibilityThree() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--reset-auth",
            "-UIPreferredContentSizeCategoryName",
            UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue
        ]
        app.launch()

        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5))

        let keepGoing = app.buttons["Keep going without an account"]
        XCTAssertTrue(keepGoing.exists)
        XCTAssertTrue(keepGoing.isHittable)
        keepGoing.tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
    }

    func testGuestHistoryPersistsAfterCopyAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-preferences", "--reset-auth", "--reset-history"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("craigslist", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: copy)
        waitForExpectations(timeout: 5)
        copy.tap()

        let listing = recentListingWithPhoto(in: app)
        XCTAssertTrue(listing.waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth"]
        app.launch()

        XCTAssertTrue(recentListingWithPhoto(in: app).waitForExistence(timeout: 5))
    }

    private func recentListingWithPhoto(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@",
            "Vintage brass table lamp",
            "photo attached"
        )).firstMatch
    }

    func testRecentListingReopensListingSheetDirectly() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--seed-history"]
        app.launch()

        let listing = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Vintage brass table lamp")).firstMatch
        XCTAssertTrue(listing.waitForExistence(timeout: 5))
        listing.tap()

        XCTAssertTrue(app.buttons["Copy listing"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["MarketplaceRow.ebay"].exists)
        XCTAssertFalse(app.staticTexts["Pick where to sell"].exists)
    }

    func testMarketplaceBestSummaryOpensListingSheetDirectly() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth", "--reset-history"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        let bestSummary = app.buttons["MarketplaceSummary.bestChance.craigslist"]
        XCTAssertTrue(bestSummary.waitForExistence(timeout: 5))
        bestSummary.tap()

        XCTAssertTrue(app.buttons["Copy listing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Craigslist"].exists)
        XCTAssertFalse(app.staticTexts["Pick where to sell"].exists)
    }

    func testListingRetakeKeepsMarketplaceAndSkipsPicker() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth", "--reset-history"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("craigslist", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))

        let retake = app.buttons["Wrong item — retake"]
        XCTAssertTrue(retake.waitForExistence(timeout: 5))
        retake.tap()

        if looksRight.waitForExistence(timeout: 5) == false {
            let rawCancellation = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "CancellationError")).firstMatch
            XCTAssertFalse(rawCancellation.exists)

            let retry = app.buttons["Try again"]
            XCTAssertTrue(retry.waitForExistence(timeout: 2))
            retry.tap()
            XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        }
        looksRight.tap()

        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["MarketplaceRow.ebay"].exists)
        XCTAssertFalse(app.staticTexts["Pick where to sell"].exists)
    }

    func testListingCanReturnToMarketplacePickerWithoutRetakingPhoto() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth", "--reset-history"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("craigslist", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Craigslist"].exists)

        let tryAnother = app.buttons["Try another marketplace"]
        XCTAssertTrue(tryAnother.waitForExistence(timeout: 5))
        tryAnother.tap()

        XCTAssertTrue(app.navigationBars["Best place to sell"].waitForExistence(timeout: 5))
        tapMarketplace("ebay", in: app)

        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["eBay"].exists)
    }

    func testCopyListingWritesOnlyListingTextToPasteboard() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth", "--reset-history", "--ui-testing-verify-clipboard"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("craigslist", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: copy)
        waitForExpectations(timeout: 5)
        copy.tap()

        let clipboardStatus = app.staticTexts["Clipboard exact listing text"]
        XCTAssertTrue(clipboardStatus.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Clipboard mismatch"].exists)
    }

    func testGenerateListingOfflineShowsToastAndRegenerateButton() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--reset-auth",
            "--reset-history",
            "--ui-testing-generate-offline"
        ]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("craigslist", in: app)

        let offlineMessage = app.staticTexts["Listing.ErrorMessage"]
        if offlineMessage.waitForExistence(timeout: 5) == false {
            XCTFail("Missing listing offline message. Current hierarchy: \(app.debugDescription)")
            return
        }
        XCTAssertEqual(offlineMessage.label, "You're offline. Reconnect and try again.")
        XCTAssertTrue(app.buttons["Regenerate"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Copy listing"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "URLError")).firstMatch.exists)

        let toast = app.descendants(matching: .any)["Toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 2))
    }

    func testSettingsThemeAndReduceMotionPersistAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-preferences", "--ui-testing-state-probe"]
        app.launch()

        assertSettingsState("Settings state: system, reduce motion off", in: app)

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let reduceMotion = app.switches["Reduce Motion"]
        XCTAssertTrue(reduceMotion.waitForExistence(timeout: 5))
        reduceMotion.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let darkTheme = app.buttons["Dark"]
        XCTAssertTrue(darkTheme.waitForExistence(timeout: 5))
        darkTheme.tap()

        assertSettingsState("Settings state: dark, reduce motion on", in: app)

        app.terminate()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--ui-testing-state-probe"]
        app.launch()

        assertSettingsState("Settings state: dark, reduce motion on", in: app)

        app.terminate()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-preferences"]
        app.launch()
        app.terminate()
    }

    func testDarkModeSellFlowReachesCopyListing() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--skip-tutorial",
            "--reset-preferences",
            "--reset-auth",
            "--reset-history",
            "--ui-testing-state-probe"
        ]
        app.launch()
        defer {
            app.terminate()
            app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-preferences"]
            app.launch()
            app.terminate()
        }

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let darkTheme = app.buttons["Dark"]
        XCTAssertTrue(darkTheme.waitForExistence(timeout: 5))
        darkTheme.tap()
        assertSettingsState("Settings state: dark, reduce motion off", in: app)

        let closeSettings = app.buttons["Close settings"]
        XCTAssertTrue(closeSettings.waitForExistence(timeout: 2))
        closeSettings.tap()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("craigslist", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Wrong item — retake"].exists)
    }

    func testM10AppStoreScreenshotsCanBeCaptured() throws {
        let screenshotURL = appStoreScreenshotDirectory()

        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-preferences", "--reset-auth", "--reset-history"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        try saveAppStoreScreenshot("01-home", in: screenshotURL)

        snap.tap()
        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Item photo"].waitForExistence(timeout: 5))
        try saveAppStoreScreenshot("02-result", in: screenshotURL)

        looksRight.tap()
        XCTAssertTrue(app.buttons["MarketplaceSummary.bestChance.craigslist"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["MarketplaceRow.craigslist"].waitForExistence(timeout: 5))
        try saveAppStoreScreenshot("03-marketplaces", in: screenshotURL)

        tapMarketplace("craigslist", in: app)
        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Generated listing text"].waitForExistence(timeout: 5))

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: copy)
        waitForExpectations(timeout: 5)
        try saveAppStoreScreenshot("04-listing", in: screenshotURL)
    }

    private func appStoreScreenshotDirectory() -> URL {
        if let explicitPath = ProcessInfo.processInfo.environment["M10_SCREENSHOT_DIR"], explicitPath.isEmpty == false {
            return URL(fileURLWithPath: explicitPath, isDirectory: true)
        }

        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AppStoreAssets")
            .appendingPathComponent("Screenshots")
            .appendingPathComponent(appStoreScreenshotDeviceFolder())
    }

    private func appStoreScreenshotDeviceFolder() -> String {
        let rawDeviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "iPhone 16 Pro"
        let deviceName = rawDeviceName.replacingOccurrences(
            of: #"^Clone \d+ of "#,
            with: "",
            options: .regularExpression
        )
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let normalized = deviceName
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "-")
        return normalized.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "-"
        }
        .joined()
    }

    private func tapMarketplace(
        _ rawValue: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let row = revealMarketplace(rawValue, in: app, file: file, line: line)

        XCTAssertTrue(row.isHittable, "Marketplace row was not hittable: \(rawValue)", file: file, line: line)
        row.tap()
    }

    private func revealMarketplace(
        _ rawValue: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let row = app.buttons["MarketplaceRow.\(rawValue)"]

        var revealAttempts = 0
        while row.waitForExistence(timeout: revealAttempts == 0 ? 3 : 0.5) == false && revealAttempts < 8 {
            app.swipeUp()
            revealAttempts += 1
        }

        XCTAssertTrue(row.exists, "Missing marketplace row: \(rawValue)", file: file, line: line)

        var hittableAttempts = 0
        while row.isHittable == false && hittableAttempts < 8 {
            app.swipeUp()
            hittableAttempts += 1
        }

        return row
    }

    private func saveAppStoreScreenshot(
        _ name: String,
        in directory: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let screenshot = XCUIScreen.main.screenshot()
        let destination = directory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: destination, options: .atomic)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let byteCount = try FileManager.default
            .attributesOfItem(atPath: destination.path)[.size] as? NSNumber
        XCTAssertGreaterThan(
            byteCount?.intValue ?? 0,
            10_000,
            "Screenshot \(name) was not written with meaningful PNG data.",
            file: file,
            line: line
        )
    }

    private func assertSettingsState(_ expected: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        if app.staticTexts[expected].waitForExistence(timeout: 5) {
            return
        }

        let probes = app.staticTexts.matching(identifier: "SettingsStateProbe")
        if probes.firstMatch.waitForExistence(timeout: 1) {
            let labels = probes.allElementsBoundByIndex.map(\.label)
            XCTAssertTrue(labels.contains(expected), "Expected \(expected), saw probes: \(labels)", file: file, line: line)
        } else {
            XCTFail("Missing settings probe for expected state: \(expected)", file: file, line: line)
        }
    }
}
