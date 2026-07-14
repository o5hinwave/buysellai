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

        let listing = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Vintage brass table lamp")).firstMatch
        XCTAssertTrue(listing.waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--ui-testing", "--skip-tutorial", "--reset-auth"]
        app.launch()

        XCTAssertTrue(listing.waitForExistence(timeout: 5))
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
