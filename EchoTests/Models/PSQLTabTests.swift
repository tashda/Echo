import XCTest
@testable import Echo

final class PSQLTabTests: XCTestCase {
    func testASCIIPlainTableFormatter() {
        let columns = ["id", "name", "email"]
        let rows = [
            ["1", "Alice", "alice@example.com"],
            ["2", "Bob", "bob@example.com"],
            ["3", "Charlie", nil]
        ]
        
        let output = ASCIIPlainTableFormatter.format(columns: columns, rows: rows, nullDisplay: "[NULL]")
        
        XCTAssertTrue(output.contains("id"))
        XCTAssertTrue(output.contains("name"))
        XCTAssertTrue(output.contains("email"))
        XCTAssertTrue(output.contains("Alice"))
        XCTAssertTrue(output.contains("bob@example.com"))
        XCTAssertTrue(output.contains("[NULL]"))
        XCTAssertTrue(output.contains("(3 rows)"))
    }
    
    func testASCIIPlainTableFormatterEmpty() {
        let output = ASCIIPlainTableFormatter.format(columns: [], rows: [])
        XCTAssertEqual(output, "")
    }
}
