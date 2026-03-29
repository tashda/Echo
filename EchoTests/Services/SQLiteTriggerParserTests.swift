import Foundation
import Testing
@testable import Echo

@Suite("SQLite Trigger SQL Parsing")
struct SQLiteTriggerParserTests {

    @Test func afterInsertTrigger() {
        let sql = "CREATE TRIGGER log_insert AFTER INSERT ON users BEGIN INSERT INTO audit(action) VALUES('insert'); END;"
        let (action, table) = SQLiteSession.parseTriggerSQL(sql)
        #expect(action == "AFTER INSERT")
        #expect(table == "users")
    }

    @Test func beforeDeleteTrigger() {
        let sql = "CREATE TRIGGER before_del BEFORE DELETE ON orders FOR EACH ROW BEGIN SELECT 1; END;"
        let (action, table) = SQLiteSession.parseTriggerSQL(sql)
        #expect(action == "BEFORE DELETE")
        #expect(table == "orders")
    }

    @Test func insteadOfUpdateTrigger() {
        let sql = "CREATE TRIGGER io_update INSTEAD OF UPDATE ON my_view BEGIN SELECT 1; END;"
        let (action, table) = SQLiteSession.parseTriggerSQL(sql)
        #expect(action == "INSTEAD OF UPDATE")
        #expect(table == "my_view")
    }

    @Test func afterUpdateTrigger() {
        let sql = "CREATE TRIGGER track_changes AFTER UPDATE ON products BEGIN INSERT INTO changes(id) VALUES(NEW.id); END;"
        let (action, table) = SQLiteSession.parseTriggerSQL(sql)
        #expect(action == "AFTER UPDATE")
        #expect(table == "products")
    }

    @Test func quotedTableName() {
        let sql = """
        CREATE TRIGGER my_trigger AFTER INSERT ON "my table" BEGIN SELECT 1; END;
        """
        let (action, table) = SQLiteSession.parseTriggerSQL(sql)
        #expect(action == "AFTER INSERT")
        #expect(table == "my table")
    }

    @Test func emptySQL() {
        let (action, table) = SQLiteSession.parseTriggerSQL("")
        #expect(action == nil)
        #expect(table == nil)
    }

    @Test func malformedSQL() {
        let (action, table) = SQLiteSession.parseTriggerSQL("NOT A VALID TRIGGER")
        #expect(action == nil)
        #expect(table == nil)
    }
}
