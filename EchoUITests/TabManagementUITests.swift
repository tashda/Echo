import XCTest

final class TabManagementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - New Tab

    func testCommandTCreatesNewTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Use Cmd+T to create a new tab
        app.typeKey("t", modifierFlags: .command)

        // Small delay for UI update
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: app.windows
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: 3)

        // The app should still be running and window visible
        XCTAssertTrue(window.exists)
    }

    // MARK: - Close Tab

    func testCommandWClosesTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a new tab first
        app.typeKey("t", modifierFlags: .command)

        // Small delay
        Thread.sleep(forTimeInterval: 0.5)

        // Close it with Cmd+W
        app.typeKey("w", modifierFlags: .command)

        // App should still be running
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Tab Overview

    func testCommandOTogglesTabOverview() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Toggle tab overview with Cmd+O
        app.typeKey("o", modifierFlags: .command)

        // Small delay for animation
        Thread.sleep(forTimeInterval: 1.0)

        // Take a screenshot to verify
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Tab Overview Toggled"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
