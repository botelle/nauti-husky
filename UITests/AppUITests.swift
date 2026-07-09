import XCTest

/// Black-box UI "driving" of the iOS app: launch it on the simulator and exercise
/// the main navigation. (watchOS does not support XCUITest, so UI driving is iOS-only.)
///
/// These are intentionally network-independent: they assert on the always-present
/// navigation chrome (title bar, toolbar, Settings sheet) rather than on spot data,
/// which only renders after a successful location + network fetch.
final class AppUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        dismissLocationPromptIfPresent()
    }

    /// The app requests location on first refresh; clear the system prompt if it shows.
    private func dismissLocationPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
    }

    func testAppLaunchesToMainScreen() {
        XCTAssertTrue(app.navigationBars["Nauti Husky"].waitForExistence(timeout: 15),
                      "Main screen navigation bar should appear on launch")
    }

    /// Drive a full round-trip: open the Settings sheet and dismiss it.
    func testSettingsSheetRoundTrip() {
        XCTAssertTrue(app.navigationBars["Nauti Husky"].waitForExistence(timeout: 15))

        app.buttons["settingsButton"].tap()
        let settings = app.navigationBars["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5),
                      "Tapping settings should present the Settings sheet")

        settings.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Nauti Husky"].waitForExistence(timeout: 5),
                      "Dismissing settings should return to the main screen")
    }
}
