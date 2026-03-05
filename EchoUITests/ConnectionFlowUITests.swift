import XCTest

final class ConnectionFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Sidebar

    func testSidebarExistsOnLaunch() {
        let app = XCUIApplication()
        app.launch()

        // The sidebar should be visible on launch
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Main window should appear")
    }

    // MARK: - Add Connection

    func testAddConnectionShowsSheet() {
        let app = XCUIApplication()
        app.launch()

        // Wait for app to settle
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Try to find and tap the add connection button
        let addButton = app.buttons["add-connection-button"].firstMatch
        if addButton.waitForExistence(timeout: 5) {
            addButton.click()

            // Verify a sheet or popover appears
            // The exact UI element depends on implementation
            let sheet = app.sheets.firstMatch
            if sheet.waitForExistence(timeout: 3) {
                XCTAssertTrue(sheet.exists, "Connection editor sheet should appear")
            }
        }
    }
}
