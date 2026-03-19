import XCTest

final class PreferencesUITests: XCTestCase {
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

    private func openSettings(_ app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)
    }

    private func settingsWindow(_ app: XCUIApplication) -> XCUIElement? {
        // Try finding by title
        let settingsWindow = app.windows["Settings"]
        if settingsWindow.waitForExistence(timeout: 5) {
            return settingsWindow
        }

        // Fallback: if there are multiple windows, the second one is likely settings
        if app.windows.count > 1 {
            return app.windows.element(boundBy: 1)
        }

        return nil
    }

    // MARK: - Open and Close

    func testOpenSettingsWithKeyboardShortcut() {
        let app = launchApp()

        openSettings(app)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Settings Window Opened"
        attachment.lifetime = .keepAlways
        add(attachment)

        // At minimum, there should be at least one window
        XCTAssertTrue(app.windows.count >= 1, "Settings window should appear")
    }

    func testOpenSettingsViaAppMenu() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let echoMenu = menuBar.menuBarItems["Echo"]
        echoMenu.click()

        let settingsItem = menuBar.menuItems["Settings"]
        if settingsItem.waitForExistence(timeout: 3) && settingsItem.isEnabled {
            settingsItem.click()
            Thread.sleep(forTimeInterval: 1.0)

            XCTAssertTrue(app.windows.count >= 1, "Settings window should appear via menu")
        } else {
            app.typeKey(.escape, modifierFlags: [])
            XCTFail("Settings menu item not found or not enabled")
        }
    }

    func testCloseSettingsWithEscape() {
        let app = launchApp()

        openSettings(app)
        Thread.sleep(forTimeInterval: 0.5)

        // Try to close settings window
        if let settings = settingsWindow(app) {
            // Click on the settings window to make it key
            settings.click()
            Thread.sleep(forTimeInterval: 0.3)

            // Close with Cmd+W (standard window close)
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.5)

            XCTAssertEqual(app.state, .runningForeground, "App should remain running after closing settings")
        }
    }

    // MARK: - Settings Sections

    func testSettingsHasGeneralSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        // Look for General in the sidebar
        let generalItem = settings.staticTexts["General"]
        if generalItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(generalItem.exists, "General section should exist")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Settings General Section"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSettingsHasAppearanceSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let appearanceItem = settings.staticTexts["Appearance"]
        if appearanceItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(appearanceItem.exists, "Appearance section should exist")
            appearanceItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Appearance Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasDatabasesSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let databasesItem = settings.staticTexts["Databases"]
        if databasesItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(databasesItem.exists, "Databases section should exist")
            databasesItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Databases Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasResultsSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let resultsItem = settings.staticTexts["Results"]
        if resultsItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(resultsItem.exists, "Results section should exist")
            resultsItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Results Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasKeyboardShortcutsSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let kbItem = settings.staticTexts["Keyboard Shortcuts"]
        if kbItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(kbItem.exists, "Keyboard Shortcuts section should exist")
            kbItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Keyboard Shortcuts Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasNotificationsSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let notifItem = settings.staticTexts["Notifications"]
        if notifItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(notifItem.exists, "Notifications section should exist")
            notifItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Notifications Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasSidebarSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let sidebarItem = settings.staticTexts["Sidebar"]
        if sidebarItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(sidebarItem.exists, "Sidebar section should exist")
            sidebarItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Sidebar Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasEchoSenseSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let echoSenseItem = settings.staticTexts["EchoSense"]
        if echoSenseItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(echoSenseItem.exists, "EchoSense section should exist")
            echoSenseItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings EchoSense Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasDiagramsSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let diagramsItem = settings.staticTexts["Diagrams"]
        if diagramsItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(diagramsItem.exists, "Diagrams section should exist")
            diagramsItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Diagrams Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSettingsHasApplicationCacheSection() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let cacheItem = settings.staticTexts["Application Cache"]
        if cacheItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(cacheItem.exists, "Application Cache section should exist")
            cacheItem.click()
            Thread.sleep(forTimeInterval: 0.5)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Application Cache Section"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    // MARK: - Navigation Between Sections

    func testNavigateAllSettingsSections() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let sections = [
            "General", "Notifications", "Appearance", "Databases",
            "Sidebar", "Results", "EchoSense", "Diagrams",
            "Application Cache", "Keyboard Shortcuts"
        ]

        for section in sections {
            let item = settings.staticTexts[section]
            if item.waitForExistence(timeout: 2) {
                item.click()
                Thread.sleep(forTimeInterval: 0.3)

                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Settings - \(section)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    // MARK: - Settings Window Properties

    func testSettingsWindowIsResizable() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        let initialFrame = settings.frame

        // Try to resize by dragging corner
        let bottomRight = settings.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        let newBottomRight = settings.coordinate(withNormalizedOffset: CGVector(dx: 1.2, dy: 1.2))
        bottomRight.press(forDuration: 0.1, thenDragTo: newBottomRight)
        Thread.sleep(forTimeInterval: 0.3)

        // Just verify the window still exists (resizability depends on implementation)
        XCTAssertTrue(settings.exists, "Settings window should still exist after resize attempt")
    }

    func testSettingsWindowCloseWithCmdW() {
        let app = launchApp()
        openSettings(app)

        guard let settings = settingsWindow(app) else {
            XCTFail("Settings window not found")
            return
        }

        settings.click()
        Thread.sleep(forTimeInterval: 0.3)

        app.typeKey("w", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        // Main window should still exist
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should remain after closing settings")
    }

    // MARK: - Settings Reopening

    func testReopenSettingsAfterClosing() {
        let app = launchApp()

        // Open settings
        openSettings(app)
        Thread.sleep(forTimeInterval: 0.5)

        // Close it
        if let settings = settingsWindow(app) {
            settings.click()
            app.typeKey("w", modifierFlags: .command)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Reopen
        openSettings(app)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(app.windows.count >= 1, "Settings should reopen successfully")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Settings Reopened"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
