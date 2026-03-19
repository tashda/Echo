import XCTest

final class QueryEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testQueryEditorAcceptsDoubleQuotedIdentifiers() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.activate()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Window should exist")

        // The query editor only appears when connected to a database.
        // If no connection is active, skip this test gracefully.
        let editor = app.descendants(matching: .textView).matching(identifier: "QueryEditorTextView").firstMatch
        guard editor.waitForExistence(timeout: 5) else {
            throw XCTSkip("Query editor not available — no database connection active")
        }

        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey(.delete, modifierFlags: [])
        editor.typeText("SELECT \"quoted\" AS name;\n")

        guard let value = editor.value as? String else {
            XCTFail("Could not read text view contents")
            return
        }

        XCTAssertTrue(value.contains("\"quoted\""), "Editor should contain the double quoted identifier")
    }
}
