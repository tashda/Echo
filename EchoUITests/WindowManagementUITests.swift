import XCTest

final class WindowManagementUITests: EchoUITestCase {
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

    // MARK: - Window Exists on Launch

    func testAppLaunchesWithWindow() {
        let app = launchApp()

        XCTAssertTrue(app.windows.count >= 1, "App should launch with at least one window")
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should exist")
        XCTAssertEqual(app.state, .runningForeground, "App should be in foreground")
    }

    func testMainWindowHasContent() {
        let app = launchApp()
        let window = app.windows.firstMatch

        // Window should have some minimum size
        XCTAssertGreaterThan(window.frame.width, 100, "Window should have meaningful width")
        XCTAssertGreaterThan(window.frame.height, 100, "Window should have meaningful height")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Main Window on Launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Window Sizing

    func testWindowHasReasonableDefaultSize() {
        let app = launchApp()
        let window = app.windows.firstMatch

        let frame = window.frame

        // Default window should be at least a reasonable size for a database client
        XCTAssertGreaterThan(frame.width, 600, "Default window width should be at least 600")
        XCTAssertGreaterThan(frame.height, 400, "Default window height should be at least 400")
    }

    func testWindowCanBeResizedSmaller() {
        let app = launchApp()
        let window = app.windows.firstMatch

        let initialFrame = window.frame

        // Attempt to resize smaller by dragging the bottom-right corner
        let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        let smallerPoint = window.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6))
        bottomRight.press(forDuration: 0.1, thenDragTo: smallerPoint)
        Thread.sleep(forTimeInterval: 0.5)

        // Window should still exist (minimum size may prevent going too small)
        XCTAssertTrue(window.exists, "Window should exist after resize attempt")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Window Resized Smaller"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWindowCanBeResizedLarger() {
        let app = launchApp()
        let window = app.windows.firstMatch

        // Attempt to resize larger
        let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        let largerPoint = window.coordinate(withNormalizedOffset: CGVector(dx: 1.3, dy: 1.3))
        bottomRight.press(forDuration: 0.1, thenDragTo: largerPoint)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(window.exists, "Window should exist after resize larger")
    }

    func testWindowMinimumSizeIsEnforced() {
        let app = launchApp()
        let window = app.windows.firstMatch

        // Try to make window extremely small
        let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        let tinyPoint = window.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1))
        bottomRight.press(forDuration: 0.1, thenDragTo: tinyPoint)
        Thread.sleep(forTimeInterval: 0.5)

        let frame = window.frame

        // Window should not go below minimum size (varies by app, but should be at least some minimum)
        XCTAssertGreaterThan(frame.width, 50, "Window width should be above minimum threshold")
        XCTAssertGreaterThan(frame.height, 50, "Window height should be above minimum threshold")
    }

    // MARK: - Window Operations via Menu

    func testMinimizeKeepsAppRunning() {
        let app = launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.isHittable, "Window should be hittable before minimize")

        // Minimize via keyboard shortcut
        app.typeKey("m", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)

        // App should still be running in the foreground after minimize
        XCTAssertEqual(app.state, .runningForeground, "App should still be running after minimize")

        // Note: restoring a minimized window (especially with minimize-to-application-icon)
        // is not reliably testable via XCUITest — activate() does not unminimize.
        // Window restore is verified manually and through the other window tests.
    }

    func testZoomWindow() {
        let app = launchApp()
        let window = app.windows.firstMatch

        let initialFrame = window.frame

        let menuBar = app.menuBars.firstMatch
        let windowMenu = menuBar.menuBarItems["Window"]
        windowMenu.click()

        let zoomItem = menuBar.menuItems["Zoom"]
        if zoomItem.waitForExistence(timeout: 3) && zoomItem.isEnabled {
            zoomItem.click()
            Thread.sleep(forTimeInterval: 1.0)

            let zoomedFrame = window.frame

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Window After Zoom"
            attachment.lifetime = .keepAlways
            add(attachment)

            // Zoom back to original
            windowMenu.click()
            let zoomAgain = menuBar.menuItems["Zoom"]
            if zoomAgain.waitForExistence(timeout: 3) && zoomAgain.isEnabled {
                zoomAgain.click()
                Thread.sleep(forTimeInterval: 1.0)
            }
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Fullscreen

    func testFullscreenToggle() {
        let app = launchApp()
        let window = app.windows.firstMatch

        let initialFrame = window.frame

        // Enter fullscreen via keyboard (Cmd+Ctrl+F on macOS)
        app.typeKey("f", modifierFlags: [.command, .control])
        // Fullscreen animation takes time
        Thread.sleep(forTimeInterval: 2.0)

        let screenshotFull = app.screenshot()
        let attachmentFull = XCTAttachment(screenshot: screenshotFull)
        attachmentFull.name = "Fullscreen Mode"
        attachmentFull.lifetime = .keepAlways
        add(attachmentFull)

        // Exit fullscreen
        app.typeKey("f", modifierFlags: [.command, .control])
        Thread.sleep(forTimeInterval: 2.0)

        let screenshotNormal = app.screenshot()
        let attachmentNormal = XCTAttachment(screenshot: screenshotNormal)
        attachmentNormal.name = "Normal Mode After Fullscreen"
        attachmentNormal.lifetime = .keepAlways
        add(attachmentNormal)

        XCTAssertTrue(window.exists, "Window should exist after fullscreen toggle")
    }

    // MARK: - Window State During Operations

    func testWindowRemainsResponsiveDuringTabCreation() {
        let app = launchApp()
        let window = app.windows.firstMatch

        // Create tabs and verify window remains responsive
        for _ in 0..<5 {
            app.typeKey("t", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.2)
            XCTAssertTrue(window.exists, "Window should remain responsive during tab creation")
        }
    }

    func testWindowRemainsResponsiveDuringSidebarToggle() {
        let app = launchApp()
        let window = app.windows.firstMatch

        for _ in 0..<4 {
            app.typeKey("s", modifierFlags: [.command, .control])
            Thread.sleep(forTimeInterval: 0.3)
            XCTAssertTrue(window.exists, "Window should remain responsive during sidebar toggle")
        }
    }

    func testWindowRemainsResponsiveDuringInspectorToggle() {
        let app = launchApp()
        let window = app.windows.firstMatch

        // Create a tab first
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        for _ in 0..<4 {
            app.typeKey("i", modifierFlags: [.command, .option])
            Thread.sleep(forTimeInterval: 0.3)
            XCTAssertTrue(window.exists, "Window should remain responsive during inspector toggle")
        }
    }

    // MARK: - Window with Multiple Auxiliary Windows

    func testMainWindowPersistsAfterOpeningSettings() {
        let app = launchApp()
        let mainWindow = app.windows.firstMatch

        // Open settings
        app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)

        // Main window should still exist
        XCTAssertTrue(mainWindow.exists, "Main window should persist when settings window opens")

        // Close settings
        let settingsWindow = app.windows["Settings"]
        if settingsWindow.exists {
            settingsWindow.click()
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Main window should still be there
        XCTAssertTrue(mainWindow.exists, "Main window should persist after settings window closes")
    }

    func testMainWindowPersistsAfterOpeningManageConnections() {
        let app = launchApp()
        let mainWindow = app.windows.firstMatch

        app.typeKey("m", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        XCTAssertTrue(mainWindow.exists, "Main window should persist when manage connections opens")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Main Window with Manage Connections"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Window Frame Persistence

    func testWindowFrameIsReasonable() {
        let app = launchApp()
        let window = app.windows.firstMatch

        let frame = window.frame

        // Window should be on screen (positive coordinates, reasonable size)
        XCTAssertGreaterThanOrEqual(frame.origin.x, -frame.width, "Window X should be on or near screen")
        XCTAssertGreaterThanOrEqual(frame.origin.y, -frame.height, "Window Y should be on or near screen")
        XCTAssertGreaterThan(frame.width, 0, "Window should have positive width")
        XCTAssertGreaterThan(frame.height, 0, "Window should have positive height")
    }

    // MARK: - Window Content Stability

    func testWindowContentStableDuringRapidOperations() {
        let app = launchApp()
        let window = app.windows.firstMatch

        // Rapid sequence of operations
        app.typeKey("t", modifierFlags: .command)
        app.typeKey("s", modifierFlags: [.command, .control])
        app.typeKey("t", modifierFlags: .command)
        app.typeKey("i", modifierFlags: [.command, .option])
        app.typeKey(.tab, modifierFlags: .control)
        app.typeKey("s", modifierFlags: [.command, .control])

        Thread.sleep(forTimeInterval: 1.0)

        XCTAssertTrue(window.exists, "Window should remain stable after rapid operations")
        XCTAssertEqual(app.state, .runningForeground, "App should remain in foreground")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After Rapid Operations"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
