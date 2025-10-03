import XCTest

final class QueryEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testQueryEditorAcceptsDoubleQuotedIdentifiers() {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_BOOT_MODE"] = "QueryEditor"
        app.launch()

        let editor = app.textViews["QueryEditorTextView"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Query editor text view should exist")

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
