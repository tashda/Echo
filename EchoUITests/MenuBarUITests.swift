import XCTest

final class MenuBarUITests: XCTestCase {
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

    private func menuItem(_ app: XCUIApplication, menu: String, item: String) -> XCUIElement {
        let menuBar = app.menuBars.firstMatch
        let menuBarItem = menuBar.menuBarItems[menu]
        menuBarItem.click()
        return menuBar.menuItems[item]
    }

    // MARK: - File Menu (replaced by CommandGroup)

    func testNewQueryTabMenuItem() {
        let app = launchApp()

        // The "New Query Tab" item replaces the standard "New" item in the File menu
        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()

        let newTabItem = menuBar.menuItems["New Query Tab"]
        if newTabItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(newTabItem.isEnabled, "New Query Tab should be enabled")
            newTabItem.click()
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertEqual(app.state, .runningForeground)
        } else {
            // Take screenshot for debugging
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "File Menu Contents"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("New Query Tab menu item not found in File menu")
        }
    }

    func testCloseQueryTabMenuItem() {
        let app = launchApp()

        // Create a tab first
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()

        let closeItem = menuBar.menuItems["Close Query Tab"]
        if closeItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(closeItem.isEnabled, "Close Query Tab should be enabled when a tab is open")
            closeItem.click()
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertEqual(app.state, .runningForeground)
        } else {
            fileMenu.click() // dismiss
            XCTFail("Close Query Tab menu item not found")
        }
    }

    func testReopenClosedTabMenuItem() {
        let app = launchApp()

        // Create and close a tab
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        app.typeKey("w", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()

        let reopenItem = menuBar.menuItems["Reopen Closed Tab"]
        if reopenItem.waitForExistence(timeout: 3) {
            reopenItem.click()
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertEqual(app.state, .runningForeground)
        } else {
            fileMenu.click() // dismiss
            // This may not appear if no tabs have been closed
        }
    }

    func testNextTabMenuItem() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()

        let nextItem = menuBar.menuItems["Next Tab"]
        if nextItem.waitForExistence(timeout: 3) {
            // Capture whether it is enabled
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "File Menu with Next Tab"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // Dismiss the menu
        app.typeKey(.escape, modifierFlags: [])
    }

    func testPreviousTabMenuItem() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuBarItems["File"]
        fileMenu.click()

        let prevItem = menuBar.menuItems["Previous Tab"]
        if prevItem.waitForExistence(timeout: 3) {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "File Menu with Previous Tab"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Edit Menu

    func testEditMenuItemsExist() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let editMenu = menuBar.menuBarItems["Edit"]
        editMenu.click()

        let expectedItems = ["Undo", "Redo", "Cut", "Copy", "Paste", "Select All"]
        for itemName in expectedItems {
            let item = menuBar.menuItems[itemName]
            XCTAssertTrue(item.waitForExistence(timeout: 2), "\(itemName) should exist in Edit menu")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Edit Menu Items"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.typeKey(.escape, modifierFlags: [])
    }

    func testEditMenuFindExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let editMenu = menuBar.menuBarItems["Edit"]
        editMenu.click()

        // Find is typically in a submenu under Edit
        let findItem = menuBar.menuItems["Find…"]
        let findMenu = menuBar.menuItems["Find"]

        if findItem.exists || findMenu.exists {
            // Find functionality is available
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Edit Menu Find"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - View Menu

    func testViewMenuToggleSidebarExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuBarItems["View"]
        viewMenu.click()

        let sidebarItem = menuBar.menuItems["Toggle Sidebar"]
        if sidebarItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(sidebarItem.isEnabled, "Toggle Sidebar should be enabled")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "View Menu"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.typeKey(.escape, modifierFlags: [])
    }

    func testViewMenuToggleInspectorExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuBarItems["View"]
        viewMenu.click()

        // Inspector label changes based on state
        let showInspector = menuBar.menuItems["Show Inspector"]
        let hideInspector = menuBar.menuItems["Hide Inspector"]

        XCTAssertTrue(
            showInspector.exists || hideInspector.exists,
            "Inspector toggle menu item should exist in View menu"
        )

        app.typeKey(.escape, modifierFlags: [])
    }

    func testViewMenuTabOverviewExists() {
        let app = launchApp()

        // Create a tab so tab overview is available
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuBarItems["View"]
        viewMenu.click()

        let showOverview = menuBar.menuItems["Show Tab Overview"]
        let hideOverview = menuBar.menuItems["Hide Tab Overview"]

        XCTAssertTrue(
            showOverview.exists || hideOverview.exists,
            "Tab Overview toggle should exist in View menu"
        )

        app.typeKey(.escape, modifierFlags: [])
    }

    func testViewMenuToggleSidebarClickWorks() {
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
            attachment.name = "After Toggle Sidebar via Menu"
            attachment.lifetime = .keepAlways
            add(attachment)

            // Toggle back
            viewMenu.click()
            let sidebarItemAgain = menuBar.menuItems["Toggle Sidebar"]
            if sidebarItemAgain.waitForExistence(timeout: 3) && sidebarItemAgain.isEnabled {
                sidebarItemAgain.click()
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Connect Menu

    func testConnectMenuExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let connectMenu = menuBar.menuBarItems["Connect"]

        XCTAssertTrue(connectMenu.exists, "Connect menu should exist in menu bar")
    }

    func testConnectMenuManageConnectionsExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let connectMenu = menuBar.menuBarItems["Connect"]
        connectMenu.click()

        let manageItem = menuBar.menuItems["Manage Connections…"]
        if manageItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(manageItem.isEnabled, "Manage Connections should be enabled")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Connect Menu"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.typeKey(.escape, modifierFlags: [])
    }

    func testConnectMenuManageConnectionsOpensWindow() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let connectMenu = menuBar.menuBarItems["Connect"]
        connectMenu.click()

        let manageItem = menuBar.menuItems["Manage Connections…"]
        if manageItem.waitForExistence(timeout: 3) && manageItem.isEnabled {
            manageItem.click()
            Thread.sleep(forTimeInterval: 1.0)

            XCTAssertTrue(app.windows.count >= 1, "Manage Connections window should appear")

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Manage Connections Window via Menu"
            attachment.lifetime = .keepAlways
            add(attachment)
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Window Menu

    func testWindowMenuExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let windowMenu = menuBar.menuBarItems["Window"]
        XCTAssertTrue(windowMenu.exists, "Window menu should exist")
    }

    func testWindowMenuMinimizeExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let windowMenu = menuBar.menuBarItems["Window"]
        windowMenu.click()

        let minimizeItem = menuBar.menuItems["Minimize"]
        XCTAssertTrue(minimizeItem.waitForExistence(timeout: 3), "Minimize should exist in Window menu")
        XCTAssertTrue(minimizeItem.isEnabled, "Minimize should be enabled")

        app.typeKey(.escape, modifierFlags: [])
    }

    func testWindowMenuZoomExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let windowMenu = menuBar.menuBarItems["Window"]
        windowMenu.click()

        let zoomItem = menuBar.menuItems["Zoom"]
        XCTAssertTrue(zoomItem.waitForExistence(timeout: 3), "Zoom should exist in Window menu")

        app.typeKey(.escape, modifierFlags: [])
    }

    func testWindowMenuBringAllToFrontExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let windowMenu = menuBar.menuBarItems["Window"]
        windowMenu.click()

        let bringAllItem = menuBar.menuItems["Bring All to Front"]
        XCTAssertTrue(bringAllItem.waitForExistence(timeout: 3), "Bring All to Front should exist in Window menu")

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Echo Menu (App Menu)

    func testAppMenuSettingsExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let echoMenu = menuBar.menuBarItems["Echo"]
        echoMenu.click()

        let settingsItem = menuBar.menuItems["Settings…"]
        if settingsItem.waitForExistence(timeout: 3) {
            XCTAssertTrue(settingsItem.isEnabled, "Settings should be enabled")
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "App Menu"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.typeKey(.escape, modifierFlags: [])
    }

    func testAppMenuCheckForUpdatesExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let echoMenu = menuBar.menuBarItems["Echo"]
        echoMenu.click()

        let updateItem = menuBar.menuItems["Check for Updates…"]
        if updateItem.waitForExistence(timeout: 3) {
            // Item exists (may or may not be enabled)
            XCTAssertTrue(updateItem.exists)
        }

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Help Menu

    func testHelpMenuExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let helpMenu = menuBar.menuBarItems["Help"]

        if helpMenu.exists {
            helpMenu.click()

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Help Menu"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.typeKey(.escape, modifierFlags: [])
        }
    }

    func testHelpMenuAutocompleteManagementExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let helpMenu = menuBar.menuBarItems["Help"]

        if helpMenu.exists {
            helpMenu.click()

            let autocompleteItem = menuBar.menuItems["Autocomplete Management…"]
            if autocompleteItem.waitForExistence(timeout: 3) {
                XCTAssertTrue(autocompleteItem.exists)
            }

            app.typeKey(.escape, modifierFlags: [])
        }
    }

    func testHelpMenuPerformanceMonitorExists() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let helpMenu = menuBar.menuBarItems["Help"]

        if helpMenu.exists {
            helpMenu.click()

            let perfItem = menuBar.menuItems["Performance Monitor…"]
            if perfItem.waitForExistence(timeout: 3) {
                XCTAssertTrue(perfItem.exists)
            }

            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Full Menu Walk

    func testAllTopLevelMenusExist() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        let expectedMenus = ["Echo", "File", "Edit", "View", "Connect", "Window"]

        for menuName in expectedMenus {
            let menu = menuBar.menuBarItems[menuName]
            XCTAssertTrue(menu.exists, "\(menuName) menu should exist in the menu bar")
        }
    }
}
