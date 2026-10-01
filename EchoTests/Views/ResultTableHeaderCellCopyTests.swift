import AppKit
import Testing
@testable import Echo

@MainActor
@Suite("Result header cell copies")
struct ResultTableHeaderCellCopyTests {
    /// AppKit copies header cells to draw the empty header past the last column. Freeing those
    /// copies must not release the original's values (it crashed drawing streamed results).
    @Test func copiesOwnTheirValues() {
        let cell = ResultTableHeaderCell(textCell: "name")
        // Longer than a small string, so it lives on the heap and can be over-released.
        cell.typeName = String(repeating: "character varying ", count: 3)
        for _ in 0..<500 {
            autoreleasepool {
                let copy = cell.copy() as? ResultTableHeaderCell
                #expect(copy?.typeName == cell.typeName)
            }
        }
        #expect(cell.typeName == String(repeating: "character varying ", count: 3))
    }
}
