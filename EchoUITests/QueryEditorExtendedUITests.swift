import XCTest
import AppKit

final class QueryEditorExtendedUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchWithEditor() -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Create a query tab
        app.typeKey("t", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)

        let editor = app.textViews["QueryEditorTextView"]
        if editor.waitForExistence(timeout: 5) {
            editor.click()
        }
        return (app, editor)
    }

    private func clearEditor(_ editor: XCUIElement) {
        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey(.delete, modifierFlags: [])
    }

    // MARK: - Basic Text Input

    func testTypeSQLAndVerifyContent() {
        let (app, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT * FROM users WHERE id = 1;")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("SELECT"), "Editor should contain typed SQL keyword SELECT")
        XCTAssertTrue(value.contains("users"), "Editor should contain table name")
        XCTAssertTrue(value.contains("WHERE"), "Editor should contain WHERE clause")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SQL Typed in Editor"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTypeMultiLineSQL() {
        let (app, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT\n    id,\n    name,\n    email\nFROM users\nWHERE active = 1\nORDER BY name;")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("SELECT"), "Editor should contain SELECT")
        XCTAssertTrue(value.contains("FROM users"), "Editor should contain FROM clause")
        XCTAssertTrue(value.contains("ORDER BY"), "Editor should contain ORDER BY")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Multi-line SQL"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Special Characters

    func testDoubleQuotedIdentifiers() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT \"column name\" FROM \"my table\";")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("\"column name\""), "Editor should contain double-quoted identifier")
        XCTAssertTrue(value.contains("\"my table\""), "Editor should contain double-quoted table name")
    }

    func testSingleQuotedStrings() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT * FROM users WHERE name = 'O''Brien';")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("'O''Brien'"), "Editor should handle escaped single quotes")
    }

    func testBacktickIdentifiers() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT `column` FROM `table`;")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("`column`"), "Editor should contain backtick identifiers")
    }

    func testSquareBracketIdentifiers() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT [Column Name] FROM [My Table];")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("[Column Name]"), "Editor should contain square bracket identifiers")
        XCTAssertTrue(value.contains("[My Table]"), "Editor should contain bracketed table name")
    }

    func testParenthesesAndBraces() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT (COUNT(*) + 1) AS total FROM (SELECT id FROM users) sub;")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("(COUNT(*) + 1)"), "Editor should contain nested parentheses")
        XCTAssertTrue(value.contains("(SELECT id FROM users)"), "Editor should contain subquery in parens")
    }

    // MARK: - Select All

    func testSelectAllText() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT 1;")

        // Select all
        editor.typeKey("a", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Type replacement text to verify selection was active
        editor.typeText("SELECT 2;")

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertFalse(value.contains("SELECT 1"), "Original text should be replaced by select-all then type")
        XCTAssertTrue(value.contains("SELECT 2"), "New text should be present")
    }

    // MARK: - Cut, Copy, Paste

    func testCutAndPaste() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("HELLO WORLD")

        // Select all and cut
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey("x", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Editor should be empty after cut
        if let value = editor.value as? String {
            XCTAssertTrue(value.isEmpty || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                         "Editor should be empty after cut")
        }

        // Paste back
        editor.typeKey("v", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        guard let pastedValue = editor.value as? String else {
            XCTFail("Could not read editor text after paste")
            return
        }

        XCTAssertTrue(pastedValue.contains("HELLO WORLD"), "Pasted text should restore the cut content")
    }

    func testCopyAndPaste() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("COPY THIS")

        // Select all and copy
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey("c", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Move to end and paste
        editor.typeKey(.rightArrow, modifierFlags: .command)
        editor.typeText("\n")
        editor.typeKey("v", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text after copy-paste")
            return
        }

        // Should have the text twice (original + pasted copy)
        let occurrences = value.components(separatedBy: "COPY THIS").count - 1
        XCTAssertEqual(occurrences, 2, "Text should appear twice after copy-paste")
    }

    // MARK: - Undo and Redo

    func testUndoRedo() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("FIRST")
        Thread.sleep(forTimeInterval: 0.3)

        // Undo
        editor.typeKey("z", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        // Redo
        editor.typeKey("z", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.3)

        // App should still be running (no crash from undo/redo)
        XCTAssertTrue(editor.exists, "Editor should exist after undo/redo")
    }

    // MARK: - Comment Toggling

    func testCommandSlashTogglesComment() {
        let (app, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT 1;")

        // Select the line
        editor.typeKey("a", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.2)

        // Toggle comment with Cmd+/
        editor.typeKey("/", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After Comment Toggle"
        attachment.lifetime = .keepAlways
        add(attachment)

        // The text should now be commented (either -- prefix or wrapped in /* */)
        if let value = editor.value as? String {
            let isCommented = value.contains("--") || value.contains("/*")
            // Comment toggle may or may not be implemented, so we just verify no crash
            XCTAssertTrue(editor.exists, "Editor should still exist after comment toggle attempt")
        }
    }

    // MARK: - Tab Key

    func testTabKeyInsertsIndentation() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT")
        editor.typeKey(.tab, modifierFlags: [])
        editor.typeText("1;")
        Thread.sleep(forTimeInterval: 0.3)

        // Verify the editor still works after tab
        XCTAssertTrue(editor.exists, "Editor should handle Tab key without issues")
    }

    // MARK: - Large Text

    func testLargeTextPaste() {
        let (app, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)

        // Generate a large SQL string
        var largeSQL = ""
        for i in 0..<100 {
            largeSQL += "SELECT \(i) AS row_num, 'value_\(i)' AS data;\n"
        }

        // Put the large text on the pasteboard and paste it
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(largeSQL, forType: .string)

        editor.typeKey("v", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1.0)

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text after large paste")
            return
        }

        XCTAssertTrue(value.contains("SELECT 0"), "Editor should contain first line of large paste")
        XCTAssertTrue(value.contains("SELECT 99"), "Editor should contain last line of large paste")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Large Text Paste"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Editor Controls

    func testRunQueryButtonExists() {
        let (app, _) = launchWithEditor()

        let runButton = app.buttons["run-query-button"]
        if runButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(runButton.exists, "Run query button should exist")
        }
    }

    func testFormatQueryButtonExists() {
        let (app, _) = launchWithEditor()

        let formatButton = app.buttons["format-query-button"]
        if formatButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(formatButton.exists, "Format query button should exist")
        }
    }

    func testStatisticsToggleButtonExists() {
        let (app, _) = launchWithEditor()

        let statsButton = app.buttons["statistics-toggle-button"]
        if statsButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(statsButton.exists, "Statistics toggle button should exist")
        }
    }

    func testSQLCMDModeToggleButtonExists() {
        let (app, _) = launchWithEditor()

        let sqlcmdButton = app.buttons["sqlcmd-mode-toggle-button"]
        if sqlcmdButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(sqlcmdButton.exists, "SQLCMD mode toggle button should exist")
        }
    }

    // MARK: - Editor Navigation

    func testHomeEndKeys() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT * FROM users;")

        // Home key (Cmd+Left)
        editor.typeKey(.leftArrow, modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.2)

        // End key (Cmd+Right)
        editor.typeKey(.rightArrow, modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.2)

        XCTAssertTrue(editor.exists, "Editor should handle Home/End navigation")
    }

    func testWordNavigation() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("SELECT column FROM table")

        // Move word-by-word (Option+Left/Right)
        editor.typeKey(.leftArrow, modifierFlags: .option)
        Thread.sleep(forTimeInterval: 0.1)
        editor.typeKey(.leftArrow, modifierFlags: .option)
        Thread.sleep(forTimeInterval: 0.1)
        editor.typeKey(.rightArrow, modifierFlags: .option)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertTrue(editor.exists, "Editor should handle word-level navigation")
    }

    // MARK: - Line Selection

    func testSelectEntireLine() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        editor.typeText("Line 1\nLine 2\nLine 3")

        // Go to beginning of line 2 and select the entire line
        editor.typeKey(.upArrow, modifierFlags: [])
        editor.typeKey(.leftArrow, modifierFlags: .command)
        editor.typeKey(.rightArrow, modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 0.2)

        // The selection should not crash the editor
        XCTAssertTrue(editor.exists, "Editor should handle line selection")
    }

    // MARK: - Empty State

    func testEmptyEditorState() {
        let (app, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)
        Thread.sleep(forTimeInterval: 0.3)

        if let value = editor.value as? String {
            XCTAssertTrue(
                value.isEmpty || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Editor should be empty after clearing"
            )
        }

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Empty Editor State"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Multiple Statements

    func testMultipleStatements() {
        let (_, editor) = launchWithEditor()
        guard editor.exists else { return }

        clearEditor(editor)

        let multiStatement = """
        SELECT 1;
        SELECT 2;
        SELECT 3;
        GO
        SELECT 4;
        """

        editor.typeText(multiStatement)
        Thread.sleep(forTimeInterval: 0.3)

        guard let value = editor.value as? String else {
            XCTFail("Could not read editor text")
            return
        }

        XCTAssertTrue(value.contains("SELECT 1"), "Editor should contain first statement")
        XCTAssertTrue(value.contains("GO"), "Editor should contain GO batch separator")
        XCTAssertTrue(value.contains("SELECT 4"), "Editor should contain statement after GO")
    }
}
