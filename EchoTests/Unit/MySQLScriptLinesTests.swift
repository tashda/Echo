import MySQLKit
import Testing
@testable import Echo

/// Where a MySQL script's statements start, and when a script has DELIMITER lines (#36).
@Suite("MySQL script lines")
struct MySQLScriptLinesTests {
    @Test func statementsStartWhereTheyAre() {
        let sql = "SELECT 1;\n\n-- a comment\nSELECT 2;\nSELECT\n  3;"
        let statements = MySQLScript.statements(sql)
        #expect(statements == ["SELECT 1", "SELECT 2", "SELECT\n  3"])
        #expect(MySQLScriptLines.startLines(of: statements, in: sql) == [0, 3, 4])
    }

    @Test func delimiterLinesAreFound() {
        let sql = "DELIMITER $$\nCREATE PROCEDURE p() BEGIN SELECT 1; END$$\nDELIMITER ;"
        #expect(MySQLScriptLines.hasDelimiterCommand(sql))
        #expect(MySQLScript.statements(sql) == ["CREATE PROCEDURE p() BEGIN SELECT 1; END"])
        #expect(!MySQLScriptLines.hasDelimiterCommand("SELECT 'DELIMITER ;'"))
    }
}
