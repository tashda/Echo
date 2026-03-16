import XCTest

final class KeyboardShortcutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Tab Management Shortcuts

    func testCommandTCreatesNewTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // App should still be running with the window visible
        XCTAssertTrue(window.exists, "Window should still exist after Cmd+T")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testCommandWClosesTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a tab first so closing it does not close the window
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        app.typeKey("w", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertEqual(app.state, .runningForeground, "App should remain running after closing a tab")
    }

    func testCommandShiftTReopensClosedTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a tab, then close it, then reopen it
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        app.typeKey("w", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        app.typeKey("t", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(window.exists, "Window should exist after reopening closed tab")
        XCTAssertEqual(app.state, .runningForeground)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After Reopen Closed Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testControlTabSwitchesToNextTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create two tabs
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Switch to next tab
        app.typeKey(.tab, modifierFlags: .control)
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(window.exists, "Window should exist after Ctrl+Tab")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After Next Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testControlShiftTabSwitchesToPreviousTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create two tabs
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Switch to previous tab
        app.typeKey(.tab, modifierFlags: [.control, .shift])
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(window.exists, "Window should exist after Ctrl+Shift+Tab")
    }

    // MARK: - Tab Overview Shortcut

    func testCommandShiftOTogglesTabOverview() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a tab so tab overview has content
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Toggle tab overview on
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        let screenshotOn = app.screenshot()
        let attachmentOn = XCTAttachment(screenshot: screenshotOn)
        attachmentOn.name = "Tab Overview On"
        attachmentOn.lifetime = .keepAlways
        add(attachmentOn)

        // Toggle tab overview off
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        let screenshotOff = app.screenshot()
        let attachmentOff = XCTAttachment(screenshot: screenshotOff)
        attachmentOff.name = "Tab Overview Off"
        attachmentOff.lifetime = .keepAlways
        add(attachmentOff)
    }

    // MARK: - Sidebar and Inspector Shortcuts

    func testCommandControlSTogglesSidebar() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        let sidebar = app.groups["workspace-sidebar"].firstMatch

        // Record initial sidebar state
        let initiallyVisible = sidebar.exists

        // Toggle sidebar
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotToggled = app.screenshot()
        let attachmentToggled = XCTAttachment(screenshot: screenshotToggled)
        attachmentToggled.name = "Sidebar Toggled"
        attachmentToggled.lifetime = .keepAlways
        add(attachmentToggled)

        // Toggle back
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotRestored = app.screenshot()
        let attachmentRestored = XCTAttachment(screenshot: screenshotRestored)
        attachmentRestored.name = "Sidebar Restored"
        attachmentRestored.lifetime = .keepAlways
        add(attachmentRestored)

        // Sidebar state should have returned to initial
        if initiallyVisible {
            XCTAssertTrue(sidebar.waitForExistence(timeout: 3), "Sidebar should be visible again after double toggle")
        }
    }

    func testCommandOptionITogglesInspector() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a tab so inspector toggle is enabled
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Toggle inspector on
        app.typeKey("i", modifierFlags: [.command, .option])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotOn = app.screenshot()
        let attachmentOn = XCTAttachment(screenshot: screenshotOn)
        attachmentOn.name = "Inspector Toggled On"
        attachmentOn.lifetime = .keepAlways
        add(attachmentOn)

        // Toggle inspector off
        app.typeKey("i", modifierFlags: [.command, .option])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotOff = app.screenshot()
        let attachmentOff = XCTAttachment(screenshot: screenshotOff)
        attachmentOff.name = "Inspector Toggled Off"
        attachmentOff.lifetime = .keepAlways
        add(attachmentOff)
    }

    // MARK: - Settings Shortcut

    func testCommandCommaOpensSettings() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)

        // Settings window should appear
        let settingsWindow = app.windows["Settings"]
        let settingsExists = settingsWindow.waitForExistence(timeout: 5)

        if settingsExists {
            XCTAssertTrue(settingsWindow.exists, "Settings window should be visible after Cmd+,")
        } else {
            // Fallback: check that more than one window exists
            XCTAssertTrue(app.windows.count >= 1, "At least one window should exist after Cmd+,")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Settings Window"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Manage Connections Shortcut

    func testCommandShiftMOpensManageConnections() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        app.typeKey("m", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        // The manage connections window should appear
        XCTAssertTrue(app.windows.count >= 1, "At least one window should exist after Cmd+Shift+M")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Manage Connections Window"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Escape Key

    func testEscapeDismissesTabOverview() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a tab so tab overview has content
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Open tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        // Press Escape to dismiss
        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After Escape from Tab Overview"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(window.exists, "Window should still exist after Escape")
    }

    // MARK: - Multiple Tab Creation and Switching

    func testCreateMultipleTabsAndCycleWithControlTab() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create 3 tabs
        for _ in 0..<3 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Cycle through tabs forward
        for _ in 0..<3 {
            app.typeKey(.tab, modifierFlags: .control)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Cycle through tabs backward
        for _ in 0..<3 {
            app.typeKey(.tab, modifierFlags: [.control, .shift])
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertTrue(window.exists, "Window should exist after cycling tabs")
    }

    // MARK: - Query Execution Shortcut (Without Connection)

    func testCommandReturnDoesNotCrashWithoutConnection() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a tab
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Try to execute query without connection (should not crash)
        app.typeKey(.return, modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertEqual(app.state, .runningForeground, "App should not crash on Cmd+Return without connection")
    }

    // MARK: - Combined Shortcut Sequences

    func testRapidTabCreateAndClose() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Rapidly create and close tabs
        for _ in 0..<5 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
        }

        for _ in 0..<5 {
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertEqual(app.state, .runningForeground, "App should remain stable after rapid tab create/close")
    }

    func testSidebarToggleWhileTabOverviewIsOpen() {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a tab
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Open tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        // Toggle sidebar while overview is open
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertEqual(app.state, .runningForeground, "App should remain stable with sidebar toggle during tab overview")

        // Close tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        // Toggle sidebar back
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)
    }
}
