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

        tapMarketplace("ebay", in: app)

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

    func testTutorialNextWalksThroughAllSlidesAndGetStartedDismisses() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-tutorial"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to BuySell."].waitForExistence(timeout: 5))

        let expectedSlides = [
            "Snap a photo.",
            "We figure out what it is.",
            "Pick where to sell.",
            "Copy and paste."
        ]

        for slide in expectedSlides {
            let next = app.buttons["Next"]
            XCTAssertTrue(next.waitForExistence(timeout: 2))
            next.tap()
            XCTAssertTrue(app.staticTexts[slide].waitForExistence(timeout: 2))
        }

        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 2))
        getStarted.tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Copy and paste."].exists)
    }

    func testTutorialSwipeGesturesNavigateBetweenSlides() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-tutorial"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to BuySell."].waitForExistence(timeout: 5))

        let leftSwipeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5))
        let leftSwipeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5))
        leftSwipeStart.press(forDuration: 0.05, thenDragTo: leftSwipeEnd)
        XCTAssertTrue(app.staticTexts["Snap a photo."].waitForExistence(timeout: 2))

        leftSwipeStart.press(forDuration: 0.05, thenDragTo: leftSwipeEnd)
        XCTAssertTrue(app.staticTexts["We figure out what it is."].waitForExistence(timeout: 2))

        let rightSwipeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5))
        let rightSwipeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5))
        rightSwipeStart.press(forDuration: 0.05, thenDragTo: rightSwipeEnd)
        XCTAssertTrue(app.staticTexts["Snap a photo."].waitForExistence(timeout: 2))
    }

    func testHomeHowItWorksReopensTutorial() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial"]
        app.launch()

        let howItWorks = app.buttons["How it works"]
        XCTAssertTrue(howItWorks.waitForExistence(timeout: 5))
        howItWorks.tap()

        XCTAssertTrue(app.staticTexts["Welcome to BuySell."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Next"].exists)
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

        XCTAssertTrue(app.staticTexts["Welcome to BuySell."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Next"].exists)
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

        XCTAssertTrue(app.staticTexts["Your past listings will show up here."].waitForExistence(timeout: 3))
        XCTAssertFalse(listing.exists)
    }

    func testAnalyzeOfflineShowsToastAndRetryButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--ui-testing-analyze-offline"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let offlineMessage = app.staticTexts["You're offline. Reconnect and try again."]
        XCTAssertTrue(offlineMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 2))

        let toast = app.descendants(matching: .any)["Toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["You're offline. Reconnect and try again."].exists)
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

        let close = app.buttons["Close"]
        XCTAssertTrue(close.exists)
        close.tap()

        XCTAssertTrue(app.buttons["Snap to sell"].waitForExistence(timeout: 5))
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

    func testGuestHistoryPersistsAfterCopyAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth", "--reset-history"]
        app.launch()

        let snap = app.buttons["Snap to sell"]
        XCTAssertTrue(snap.waitForExistence(timeout: 5))
        snap.tap()

        let looksRight = app.buttons["Looks right — pick where to sell"]
        XCTAssertTrue(looksRight.waitForExistence(timeout: 5))
        looksRight.tap()

        tapMarketplace("ebay", in: app)

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

        let bestSummary = app.buttons["MarketplaceSummary.best.craigslist"]
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

        tapMarketplace("ebay", in: app)

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

        tapMarketplace("ebay", in: app)

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

        tapMarketplace("ebay", in: app)

        let copy = app.buttons["Copy listing"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Wrong item — retake"].exists)
    }

    private func tapMarketplace(
        _ rawValue: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let row = app.buttons["MarketplaceRow.\(rawValue)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing marketplace row: \(rawValue)", file: file, line: line)

        var attempts = 0
        while row.isHittable == false && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(row.isHittable, "Marketplace row was not hittable: \(rawValue)", file: file, line: line)
        row.tap()
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
