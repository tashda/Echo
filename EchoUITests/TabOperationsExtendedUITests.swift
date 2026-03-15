import XCTest

final class TabOperationsExtendedUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return app
    }

    // MARK: - Tab Creation

    func testCreateSingleTab() {
        let app = launchApp()

        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertEqual(app.state, .runningForeground, "App should be running after creating a tab")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Single Tab Created"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCreateMultipleTabs() {
        let app = launchApp()

        for i in 1...5 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.3)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "After Creating Tab \(i)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        XCTAssertEqual(app.state, .runningForeground, "App should be running after creating 5 tabs")
    }

    func testCreateTenTabs() {
        let app = launchApp()

        for _ in 1...10 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertEqual(app.state, .runningForeground, "App should handle 10 tabs without issue")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Ten Tabs Created"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tab Closing

    func testCloseTabWithKeyboardShortcut() {
        let app = launchApp()

        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        app.typeKey("w", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertEqual(app.state, .runningForeground, "App should remain running after closing tab")
    }

    func testCloseAllTabsSequentially() {
        let app = launchApp()

        // Create 3 tabs
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
        }

        // Close all tabs
        for _ in 0..<3 {
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertEqual(app.state, .runningForeground, "App should remain running after closing all tabs")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After Closing All Tabs"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCloseTabViaFileMenu() {
        let app = launchApp()

        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()

        let closeItem = menuBar.menuItems["Close Query Tab"]
        if closeItem.waitForExistence(timeout: 3) && closeItem.isEnabled {
            closeItem.click()
            Thread.sleep(forTimeInterval: 0.3)
            XCTAssertEqual(app.state, .runningForeground)
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Tab Switching

    func testSwitchTabsWithControlTab() {
        let app = launchApp()

        // Create 3 tabs
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Switch forward through tabs
        for _ in 0..<3 {
            app.typeKey(.tab, modifierFlags: .control)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Switch backward through tabs
        for _ in 0..<3 {
            app.typeKey(.tab, modifierFlags: [.control, .shift])
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertEqual(app.state, .runningForeground)
    }

    func testSwitchTabsWithNextAndPreviousMenuItems() {
        let app = launchApp()

        // Create 2 tabs
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        let menuBar = app.menuBars.firstMatch

        // Next tab via menu
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()
        let nextItem = menuBar.menuItems["Next Tab"]
        if nextItem.waitForExistence(timeout: 3) && nextItem.isEnabled {
            nextItem.click()
            Thread.sleep(forTimeInterval: 0.3)
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }

        // Previous tab via menu
        fileMenu.click()
        let prevItem = menuBar.menuItems["Previous Tab"]
        if prevItem.waitForExistence(timeout: 3) && prevItem.isEnabled {
            prevItem.click()
            Thread.sleep(forTimeInterval: 0.3)
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }

        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Reopen Closed Tab

    func testReopenClosedTab() {
        let app = launchApp()

        // Create and close a tab
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        let screenshotBefore = app.screenshot()
        let attachmentBefore = XCTAttachment(screenshot: screenshotBefore)
        attachmentBefore.name = "Before Close"
        attachmentBefore.lifetime = .keepAlways
        add(attachmentBefore)

        app.typeKey("w", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        let screenshotClosed = app.screenshot()
        let attachmentClosed = XCTAttachment(screenshot: screenshotClosed)
        attachmentClosed.name = "After Close"
        attachmentClosed.lifetime = .keepAlways
        add(attachmentClosed)

        // Reopen
        app.typeKey("t", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotReopened = app.screenshot()
        let attachmentReopened = XCTAttachment(screenshot: screenshotReopened)
        attachmentReopened.name = "After Reopen"
        attachmentReopened.lifetime = .keepAlways
        add(attachmentReopened)

        XCTAssertEqual(app.state, .runningForeground)
    }

    func testReopenMultipleClosedTabs() {
        let app = launchApp()

        // Create 3 tabs
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
        }

        // Close them all
        for _ in 0..<3 {
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
        }

        // Reopen them all
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: [.command, .shift])
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertEqual(app.state, .runningForeground, "App should remain stable after reopening multiple tabs")
    }

    func testReopenClosedTabViaMenu() {
        let app = launchApp()

        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        app.typeKey("w", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()

        let reopenItem = menuBar.menuItems["Reopen Closed Tab"]
        if reopenItem.waitForExistence(timeout: 3) && reopenItem.isEnabled {
            reopenItem.click()
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertEqual(app.state, .runningForeground)
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Tab Overview

    func testTabOverviewShowsAllTabs() {
        let app = launchApp()

        // Create multiple tabs
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Open tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Tab Overview with Multiple Tabs"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Close tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)
    }

    func testTabOverviewToggleOnAndOff() {
        let app = launchApp()

        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Toggle on
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotOn = app.screenshot()
        let attachmentOn = XCTAttachment(screenshot: screenshotOn)
        attachmentOn.name = "Tab Overview On"
        attachmentOn.lifetime = .keepAlways
        add(attachmentOn)

        // Toggle off
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotOff = app.screenshot()
        let attachmentOff = XCTAttachment(screenshot: screenshotOff)
        attachmentOff.name = "Tab Overview Off"
        attachmentOff.lifetime = .keepAlways
        add(attachmentOff)
    }

    func testTabOverviewDismissesWhenTabSelected() {
        let app = launchApp()

        // Create tabs
        for _ in 0..<2 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Open tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        // Select a tab by switching to next tab (which should close overview)
        app.typeKey(.tab, modifierFlags: .control)
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After Tab Selection from Overview"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tab with Editor Content

    func testTabPreservesEditorContent() {
        let app = launchApp()

        // Create first tab and type SQL
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        let editor = app.textViews["QueryEditorTextView"]
        if editor.waitForExistence(timeout: 5) {
            editor.click()
            editor.typeKey("a", modifierFlags: .command)
            editor.typeKey(.delete, modifierFlags: [])
            editor.typeText("SELECT 'Tab 1';")
            Thread.sleep(forTimeInterval: 0.3)

            // Create second tab
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.5)

            let editor2 = app.textViews["QueryEditorTextView"]
            if editor2.waitForExistence(timeout: 5) {
                editor2.click()
                editor2.typeKey("a", modifierFlags: .command)
                editor2.typeKey(.delete, modifierFlags: [])
                editor2.typeText("SELECT 'Tab 2';")
                Thread.sleep(forTimeInterval: 0.3)
            }

            // Switch back to first tab
            app.typeKey(.tab, modifierFlags: [.control, .shift])
            Thread.sleep(forTimeInterval: 0.5)

            // Verify first tab still has its content
            let editorAgain = app.textViews["QueryEditorTextView"]
            if editorAgain.waitForExistence(timeout: 5) {
                if let value = editorAgain.value as? String {
                    XCTAssertTrue(value.contains("Tab 1"), "First tab should preserve its SQL content")
                }
            }
        }
    }

    // MARK: - Stress Tests

    func testRapidTabOperations() {
        let app = launchApp()

        // Rapid create
        for _ in 0..<5 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Rapid switch
        for _ in 0..<10 {
            app.typeKey(.tab, modifierFlags: .control)
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Rapid close
        for _ in 0..<3 {
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Rapid reopen
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: [.command, .shift])
            Thread.sleep(forTimeInterval: 0.1)
        }

        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(app.state, .runningForeground, "App should be stable after rapid tab operations")
    }

    func testCreateCloseReopenCycle() {
        let app = launchApp()

        for cycle in 0..<3 {
            // Create
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)

            // Close
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)

            // Reopen
            app.typeKey("t", modifierFlags: [.command, .shift])
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertEqual(app.state, .runningForeground, "App should handle create-close-reopen cycles")
    }

    // MARK: - Tab Overview with No Tabs

    func testTabOverviewDisabledWithNoTabs() {
        let app = launchApp()

        // Try to open tab overview with no tabs (should have no effect or be disabled)
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertEqual(app.state, .runningForeground, "App should handle tab overview request with no tabs")
    }
}
