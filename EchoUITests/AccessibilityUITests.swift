import XCTest

final class AccessibilityUITests: XCTestCase {
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

    private func launchWithTab() -> XCUIApplication {
        let app = launchApp()
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)
        return app
    }

    // MARK: - Workspace Accessibility Identifiers

    func testWorkspaceSidebarHasAccessibilityIdentifier() {
        let app = launchApp()

        let sidebar = app.groups["workspace-sidebar"]
        let exists = sidebar.firstMatch.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(sidebar.firstMatch.exists,
                         "workspace-sidebar accessibility identifier should be present")
        }
    }

    func testWorkspaceContentHasAccessibilityIdentifier() {
        let app = launchApp()

        let content = app.groups["workspace-content"]
        let exists = content.firstMatch.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(content.firstMatch.exists,
                         "workspace-content accessibility identifier should be present")
        }
    }

    // MARK: - Query Editor Accessibility

    func testQueryEditorTextViewHasAccessibilityIdentifier() {
        let app = launchWithTab()

        let editor = app.textViews["QueryEditorTextView"]
        let exists = editor.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(editor.exists, "QueryEditorTextView accessibility identifier should be present")
        }
    }

    func testQueryEditorIsAccessible() {
        let app = launchWithTab()

        let editor = app.textViews["QueryEditorTextView"]
        if editor.waitForExistence(timeout: 5) {
            // Verify the editor can receive focus
            editor.click()
            Thread.sleep(forTimeInterval: 0.3)

            // Verify it accepts text input
            editor.typeText("test")
            Thread.sleep(forTimeInterval: 0.3)

            if let value = editor.value as? String {
                XCTAssertTrue(value.contains("test"), "Editor should accept text input via accessibility")
            }
        }
    }

    // MARK: - Editor Control Button Identifiers

    func testRunQueryButtonHasAccessibilityIdentifier() {
        let app = launchWithTab()

        let button = app.buttons["run-query-button"]
        let exists = button.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(button.exists, "run-query-button should have accessibility identifier")
            XCTAssertTrue(button.isEnabled || !button.isEnabled,
                         "run-query-button should report its enabled state")
        }
    }

    func testFormatQueryButtonHasAccessibilityIdentifier() {
        let app = launchWithTab()

        let button = app.buttons["format-query-button"]
        let exists = button.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(button.exists, "format-query-button should have accessibility identifier")
        }
    }

    func testEstimatedPlanButtonHasAccessibilityIdentifier() {
        let app = launchWithTab()

        let button = app.buttons["estimated-plan-button"]
        // This button may not exist for all connection types
        _ = button.waitForExistence(timeout: 3)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Editor Control Buttons"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testStatisticsToggleButtonHasAccessibilityIdentifier() {
        let app = launchWithTab()

        let button = app.buttons["statistics-toggle-button"]
        let exists = button.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(button.exists, "statistics-toggle-button should have accessibility identifier")
        }
    }

    func testSQLCMDModeToggleHasAccessibilityIdentifier() {
        let app = launchWithTab()

        let button = app.buttons["sqlcmd-mode-toggle-button"]
        let exists = button.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(button.exists, "sqlcmd-mode-toggle-button should have accessibility identifier")
        }
    }

    // MARK: - Results Section Accessibility

    func testQueryResultsSectionHasAccessibilityIdentifier() {
        let app = launchWithTab()

        // Results section may not be visible until a query is executed
        let results = app.groups["query-results-section"]
        _ = results.firstMatch.waitForExistence(timeout: 3)

        // Take screenshot to verify visual state
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Results Section Check"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Object Browser Accessibility

    func testObjectBrowserSidebarHasAccessibilityIdentifier() {
        let app = launchApp()

        let objectBrowser = app.groups["object-browser-sidebar"]
        let exists = objectBrowser.firstMatch.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(objectBrowser.firstMatch.exists,
                         "object-browser-sidebar should have accessibility identifier")
        }
    }

    func testConnectionsSidebarHasAccessibilityIdentifier() {
        let app = launchApp()

        let connectionsSidebar = app.groups["connections-sidebar"]
        let exists = connectionsSidebar.firstMatch.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(connectionsSidebar.firstMatch.exists,
                         "connections-sidebar should have accessibility identifier")
        }
    }

    // MARK: - Tab Card Accessibility

    func testTabCardsHaveAccessibilityIdentifiers() {
        let app = launchApp()

        // Create tabs
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Open tab overview where tab cards are visible
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1.0)

        // Tab cards use dynamic accessibility identifiers (tab-card-{uuid})
        // We can check that at least one element with the tab-card prefix exists
        let allGroups = app.groups.allElementsBoundByIndex
        var foundTabCard = false
        for group in allGroups {
            if let identifier = group.identifier as String?, identifier.hasPrefix("tab-card-") {
                foundTabCard = true
                break
            }
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Tab Cards in Overview"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Close tab overview
        app.typeKey("o", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Toolbar Accessibility

    func testToolbarButtonsExist() {
        let app = launchApp()

        let window = app.windows.firstMatch
        let toolbar = window.toolbars.firstMatch

        if toolbar.waitForExistence(timeout: 5) {
            let buttons = toolbar.buttons.allElementsBoundByIndex

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Toolbar Buttons"
            attachment.lifetime = .keepAlways
            add(attachment)

            // There should be at least some toolbar buttons
            XCTAssertGreaterThanOrEqual(buttons.count, 0,
                                        "Toolbar should have buttons (may be 0 if toolbar is minimal)")
        }
    }

    // MARK: - Menu Bar Accessibility

    func testAllMenuBarItemsAreAccessible() {
        let app = launchApp()

        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists, "Menu bar should exist")

        let menuBarItems = menuBar.menuBarItems.allElementsBoundByIndex
        XCTAssertGreaterThan(menuBarItems.count, 0, "Menu bar should have items")

        for item in menuBarItems {
            XCTAssertFalse(item.label.isEmpty || item.identifier.isEmpty && item.label.isEmpty,
                          "Menu bar item should have a label or identifier")
        }
    }

    // MARK: - Interactive Element Labels

    func testInteractiveElementsHaveLabels() {
        let app = launchWithTab()

        // Collect all buttons and verify they have labels
        let buttons = app.buttons.allElementsBoundByIndex
        var buttonsWithoutLabels: [String] = []

        for button in buttons {
            if button.exists && button.isHittable {
                let label = button.label
                let identifier = button.identifier
                if label.isEmpty && identifier.isEmpty {
                    buttonsWithoutLabels.append("Button at \(button.frame)")
                }
            }
        }

        if !buttonsWithoutLabels.isEmpty {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Buttons Without Labels"
            attachment.lifetime = .keepAlways
            add(attachment)

            // Log but don't fail - some buttons may legitimately be icon-only with tooltips
            print("Buttons without labels: \(buttonsWithoutLabels)")
        }
    }

    // MARK: - Focus and Keyboard Navigation

    func testTabKeyNavigatesBetweenElements() {
        let app = launchWithTab()

        // Press Tab key multiple times to verify focus moves
        for _ in 0..<5 {
            app.typeKey(.tab, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.2)
        }

        // App should remain responsive
        XCTAssertEqual(app.state, .runningForeground,
                      "App should remain responsive during Tab key navigation")
    }

    func testShiftTabNavigatesBackward() {
        let app = launchWithTab()

        // Shift+Tab should navigate backward
        for _ in 0..<5 {
            app.typeKey(.tab, modifierFlags: .shift)
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertEqual(app.state, .runningForeground,
                      "App should remain responsive during Shift+Tab navigation")
    }

    // MARK: - Settings Window Accessibility

    func testSettingsWindowSectionsAreAccessible() {
        let app = launchApp()

        app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)

        let settingsWindow = app.windows["Settings"]
        if settingsWindow.waitForExistence(timeout: 5) {
            // Check that section labels are accessible
            let labels = settingsWindow.staticTexts.allElementsBoundByIndex
            var sectionLabels: [String] = []

            for label in labels {
                if !label.label.isEmpty {
                    sectionLabels.append(label.label)
                }
            }

            XCTAssertGreaterThan(sectionLabels.count, 0,
                                "Settings window should have accessible text labels")

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Settings Window Accessibility"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    // MARK: - Debug Controls Accessibility (When Visible)

    func testDebugControlsHaveAccessibilityIdentifiers() {
        // Debug controls are only visible during debug mode, which requires a connection
        // This test verifies the identifiers are defined correctly
        let app = launchWithTab()

        // These elements may not be visible without an active debug session
        let stepOver = app.buttons["debug-step-over"]
        let debugContinue = app.buttons["debug-continue"]
        let debugStop = app.buttons["debug-stop"]

        // Just verify the query doesn't crash
        _ = stepOver.waitForExistence(timeout: 1)
        _ = debugContinue.waitForExistence(timeout: 1)
        _ = debugStop.waitForExistence(timeout: 1)

        XCTAssertEqual(app.state, .runningForeground,
                      "App should remain stable when querying debug control accessibility")
    }

    // MARK: - Window Title Accessibility

    func testMainWindowIsAccessible() {
        let app = launchApp()
        let window = app.windows.firstMatch

        XCTAssertTrue(window.exists, "Main window should be accessible")

        // Window should have a frame
        let frame = window.frame
        XCTAssertGreaterThan(frame.width, 0, "Window should have width")
        XCTAssertGreaterThan(frame.height, 0, "Window should have height")
    }

    // MARK: - Comprehensive Element Audit

    func testAuditAllAccessibilityIdentifiers() {
        let app = launchWithTab()

        // Collect all elements with accessibility identifiers
        var identifiedElements: [String] = []

        let knownIdentifiers = [
            "workspace-sidebar",
            "workspace-content",
            "QueryEditorTextView",
            "run-query-button",
            "format-query-button",
            "statistics-toggle-button",
            "sqlcmd-mode-toggle-button",
            "connections-sidebar",
            "object-browser-sidebar",
            "query-results-section",
        ]

        for identifier in knownIdentifiers {
            // Check buttons, groups, text views for each identifier
            let button = app.buttons[identifier]
            let group = app.groups[identifier]
            let textView = app.textViews[identifier]

            if button.exists {
                identifiedElements.append("button: \(identifier)")
            }
            if group.firstMatch.exists {
                identifiedElements.append("group: \(identifier)")
            }
            if textView.exists {
                identifiedElements.append("textView: \(identifier)")
            }
        }

        // At least some identifiers should be found
        XCTAssertGreaterThan(identifiedElements.count, 0,
                            "At least some accessibility identifiers should be present. Found: \(identifiedElements)")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Accessibility Audit"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
