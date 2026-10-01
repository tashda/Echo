import Testing
@testable import Echo

@Suite("Extra result set sorting")
struct AdditionalResultSetGridTests {
    @Test func numbersSortByValueWithNullsLast() {
        let column = ColumnInfo(name: "n", dataType: "int4")
        let order = AdditionalResultSetGrid.sortedRowOrder(values: ["10", nil, "9", "100"], column: column, ascending: true)
        #expect(order == [2, 0, 3, 1])
    }

    @Test func textSortsDescending() {
        let column = ColumnInfo(name: "t", dataType: "text")
        let order = AdditionalResultSetGrid.sortedRowOrder(values: ["b", "a", "c"], column: column, ascending: false)
        #expect(order == [2, 0, 1])
    }
}
