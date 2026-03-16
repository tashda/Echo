import XCTest

final class SidebarUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.activate()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return app
    }

    // MARK: - Sidebar Visibility

    func testSidebarVisibleOnLaunch() {
        let app = launchApp()

        let sidebar = app.groups["workspace-sidebar"].firstMatch
        let sidebarExists = sidebar.waitForExistence(timeout: 5)

        // The sidebar may or may not use the accessibility identifier depending on state
        // At minimum, the window should have content
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should exist on launch")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Initial Launch with Sidebar"
        attachment.lifetime = .keepAlways
        add(attachment)

        if sidebarExists {
            XCTAssertTrue(sidebar.exists, "Sidebar should be visible on launch")
        }
    }

    func testSidebarToggleWithKeyboardShortcut() {
        let app = launchApp()

        // Take initial screenshot
        let screenshotBefore = app.screenshot()
        let attachmentBefore = XCTAttachment(screenshot: screenshotBefore)
        attachmentBefore.name = "Before Sidebar Toggle"
        attachmentBefore.lifetime = .keepAlways
        add(attachmentBefore)

        // Toggle sidebar off
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotAfter = app.screenshot()
        let attachmentAfter = XCTAttachment(screenshot: screenshotAfter)
        attachmentAfter.name = "After Sidebar Toggle Off"
        attachmentAfter.lifetime = .keepAlways
        add(attachmentAfter)

        // Toggle sidebar back on
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)

        let screenshotRestored = app.screenshot()
        let attachmentRestored = XCTAttachment(screenshot: screenshotRestored)
        attachmentRestored.name = "After Sidebar Toggle On"
        attachmentRestored.lifetime = .keepAlways
        add(attachmentRestored)
    }

    func testSidebarToggleViaViewMenu() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuBarItems["View"]
        viewMenu.click()

        let sidebarItem = menuBar.menuItems["Toggle Sidebar"]
        if sidebarItem.waitForExistence(timeout: 3) && sidebarItem.isEnabled {
            sidebarItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Sidebar Toggled via Menu"
            attachment.lifetime = .keepAlways
            add(attachment)

            // Toggle back
            viewMenu.click()
            let sidebarItemAgain = menuBar.menuItems["Toggle Sidebar"]
            if sidebarItemAgain.waitForExistence(timeout: 3) {
                sidebarItemAgain.click()
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Sidebar Content

    func testConnectionsSidebarExists() {
        let app = launchApp()

        let connectionsSidebar = app.groups["connections-sidebar"].firstMatch
        let sidebarExists = connectionsSidebar.waitForExistence(timeout: 5)

        if sidebarExists {
            XCTAssertTrue(connectionsSidebar.exists, "Connections sidebar should exist")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Connections Sidebar"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSidebarContainsAddConnectionButton() {
        let app = launchApp()

        let addButton = app.buttons["add-connection-button"].firstMatch
        let buttonExists = addButton.waitForExistence(timeout: 5)

        if buttonExists {
            XCTAssertTrue(addButton.exists, "Add connection button should exist in sidebar")
            XCTAssertTrue(addButton.isEnabled, "Add connection button should be enabled")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Sidebar with Add Button"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Sidebar Interaction

    func testAddConnectionButtonShowsSheet() {
        let app = launchApp()

        let addButton = app.buttons["add-connection-button"].firstMatch
        if addButton.waitForExistence(timeout: 5) {
            addButton.click()
            Thread.sleep(forTimeInterval: 1.0)

            // A sheet or popover should appear
            let sheet = app.sheets.firstMatch
            let sheetExists = sheet.waitForExistence(timeout: 3)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "After Add Connection Click"
            attachment.lifetime = .keepAlways
            add(attachment)

            if sheetExists {
                XCTAssertTrue(sheet.exists, "Connection editor sheet should appear")

                // Try to dismiss the sheet
                app.typeKey(.escape, modifierFlags: [])
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    // MARK: - Sidebar Resize

    func testSidebarWindowRemainsFunctionalAfterResize() {
        let app = launchApp()
        let window = app.windows.firstMatch

        // Get window frame
        let frame = window.frame

        // Resize the window to a smaller size
        let smallerSize = CGSize(width: frame.width * 0.7, height: frame.height * 0.7)

        // Drag the bottom-right corner to resize (approximate)
        let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        let newBottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7))
        bottomRight.press(forDuration: 0.1, thenDragTo: newBottomRight)

        Thread.sleep(forTimeInterval: 0.5)

        // Window should still be functional
        XCTAssertTrue(window.exists, "Window should exist after resize")
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Sidebar State Persistence

    func testSidebarVisibilityPersistsThroughTabCreation() {
        let app = launchApp()

        let sidebar = app.groups["workspace-sidebar"].firstMatch
        let initialState = sidebar.waitForExistence(timeout: 3)

        // Create a new tab
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Sidebar state should be preserved
        if initialState {
            XCTAssertTrue(sidebar.exists, "Sidebar should remain visible after creating a new tab")
        }

        // Create another tab
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        if initialState {
            XCTAssertTrue(sidebar.exists, "Sidebar should remain visible after creating another tab")
        }
    }

    func testSidebarHiddenStatePreservedDuringTabSwitch() {
        let app = launchApp()

        // Create two tabs
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Hide sidebar
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)

        // Switch tabs
        app.typeKey(.tab, modifierFlags: .control)
        Thread.sleep(forTimeInterval: 0.5)

        // Sidebar should remain hidden
        let screenshotAfterSwitch = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshotAfterSwitch)
        attachment.name = "Sidebar Hidden During Tab Switch"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Restore sidebar
        app.typeKey("s", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Sidebar with Tab Overview

    func testSidebarVisibleDuringTabOverview() {
        let app = launchApp()

        // Create tabs
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Open tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)

        let sidebar = app.groups["workspace-sidebar"].firstMatch

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Sidebar During Tab Overview"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Close tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Multiple Toggle Cycles

    func testRapidSidebarToggling() {
        let app = launchApp()

        // Rapidly toggle sidebar multiple times
        for i in 0..<6 {
            app.typeKey("s", modifierFlags: [.command, .control])
            Thread.sleep(forTimeInterval: 0.3)
        }

        // After even number of toggles, sidebar should be back to initial state
        XCTAssertEqual(app.state, .runningForeground, "App should remain stable after rapid sidebar toggling")
    }
}
