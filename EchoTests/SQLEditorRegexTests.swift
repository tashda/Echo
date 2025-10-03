import XCTest
@testable import Echo

final class SQLEditorRegexTests: XCTestCase {
    func testDoubleQuotedStringPatternCompiles() {
        XCTAssertNoThrow(try NSRegularExpression(pattern: SQLEditorRegex.doubleQuotedStringPattern))
    }

    func testMatchesSimpleIdentifiers() {
        let regex = SQLEditorRegex.doubleQuotedStringRegex
        let sql = "SELECT \"customer\" FROM \"orders\";"
        let matches = regex.matches(
            in: sql,
            range: NSRange(sql.startIndex..<sql.endIndex, in: sql)
        )
        XCTAssertEqual(matches.count, 2)
        let tokens = matches.compactMap { Range($0.range, in: sql).map { String(sql[$0]) } }
        XCTAssertEqual(tokens, ["\"customer\"", "\"orders\""])
    }

    func testAllowsEscapedDoubleQuotes() {
        let regex = SQLEditorRegex.doubleQuotedStringRegex
        let sql = "SELECT \"He said \"\"Hello\"\"\" AS quote;"
        let matches = regex.matches(
            in: sql,
            range: NSRange(sql.startIndex..<sql.endIndex, in: sql)
        )
        XCTAssertEqual(matches.count, 1)
        if let matchRange = matches.first, let range = Range(matchRange.range, in: sql) {
            XCTAssertEqual(sql[range], "\"He said \"\"Hello\"\"\"")
        } else {
            XCTFail("Expected escaped quote string to match")
        }
    }

    func testDoesNotMatchUnterminatedString() {
        let regex = SQLEditorRegex.doubleQuotedStringRegex
        let sql = "SELECT \"unterminated FROM table;"
        let matches = regex.matches(
            in: sql,
            range: NSRange(sql.startIndex..<sql.endIndex, in: sql)
        )
        XCTAssertEqual(matches.count, 0)
    }
}
