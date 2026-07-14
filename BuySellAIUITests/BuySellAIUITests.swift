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

        let ebay = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "eBay")).firstMatch
        XCTAssertTrue(ebay.waitForExistence(timeout: 5))
        ebay.tap()

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
}
