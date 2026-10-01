import Foundation
import Testing
@testable import Echo

/// Where the editor marks a MySQL error: the line the server names, narrowed to the text it
/// stopped at (#39).
@Suite("MySQL error marks")
struct MySQLErrorMarkTests {
    private let syntax = "You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'FORM orders' at line 2"

    @Test func readsTheLineAndTheText() throws {
        let pointer = try #require(QueryErrorMarker.MySQLPointer(message: syntax))
        #expect(pointer.line == 2)
        #expect(pointer.near == "FORM orders")
        #expect(QueryErrorMarker.MySQLPointer(message: "Table 'shop.t' doesn't exist") == nil)
    }

    @Test func marksTheWordOnThatLine() throws {
        let editor = "-- report\nSELECT id\nFORM orders"
        let sent = "SELECT id\nFORM orders"
        let located = try #require(QueryErrorMarker.locate(sent, in: editor, runRange: nil))
        let pointer = try #require(QueryErrorMarker.MySQLPointer(message: syntax))
        let mark = try #require(QueryErrorMarker.mysqlMark(pointer, in: located))
        #expect((editor as NSString).substring(with: mark.range) == "FORM")
        #expect(mark.line == 3)
    }
}
