import XCTest

/// UI driving with deterministic offline content via demo mode (`-UITestDemo`).
/// Because demo mode skips location + network, these assert on real rendered
/// content (the spot and the verdict), not just navigation chrome.
final class DemoModeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestDemo"]
        app.launch()
    }

    func testShowsDemoSpotAndGoodVerdict() {
        XCTAssertTrue(app.staticTexts["Demo Beach"].waitForExistence(timeout: 10),
                      "Demo mode should display the fixed demo spot")
        XCTAssertTrue(app.staticTexts["Good to go"].waitForExistence(timeout: 5),
                      "Cool, clear demo conditions should yield a 'Good to go' verdict")
    }

    func testSpotPickerOpensListInDemoMode() {
        let picker = app.buttons["spotPickerButton"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10),
                      "With content loaded, the spot picker should be present")
        picker.tap()
        XCTAssertTrue(app.navigationBars["Swim spots"].waitForExistence(timeout: 5),
                      "Tapping the picker should open the Swim spots list")
        app.navigationBars["Swim spots"].buttons["Done"].tap()
    }
}
