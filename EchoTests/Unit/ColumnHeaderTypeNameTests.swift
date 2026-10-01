import Testing
@testable import Echo

/// The results header shows a column's type as people know it, not the OID Echo carries for
/// PostgreSQL values.
@Suite("Results header type")
struct ColumnHeaderTypeNameTests {
    @Test func postgresTypesLeaveOutTheirOID() {
        #expect(ColumnInfo(name: "d", dataType: "DATE(1082)").headerTypeName(on: .postgresql) == "DATE")
        #expect(ColumnInfo(name: "t", dataType: "TEXT[](1009)").headerTypeName(on: .postgresql) == "TEXT[]")
        #expect(ColumnInfo(name: "g", dataType: "GENDER(16475)").headerTypeName(on: .postgresql) == "GENDER")
    }

    @Test func otherTypesStayAsTheyAre() {
        #expect(ColumnInfo(name: "n", dataType: "nvarchar(50)").headerTypeName(on: .microsoftSQL) == "nvarchar(50)")
        #expect(ColumnInfo(name: "d", dataType: "DECIMAL(10,2)").headerTypeName(on: .postgresql) == "DECIMAL(10,2)")
        #expect(ColumnInfo(name: "v", dataType: "VARCHAR(255)").headerTypeName(on: .sqlite) == "VARCHAR(255)")
        #expect(ColumnInfo(name: "c", dataType: "CHAR(16)").headerTypeName(on: .mysql) == "CHAR(16)")
        #expect(ColumnInfo(name: "i", dataType: "int").headerTypeName(on: nil) == "int")
    }
}
