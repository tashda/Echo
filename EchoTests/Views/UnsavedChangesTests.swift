import Testing
@testable import Echo

/// Owner, 2026-10-01: query tabs ask before unsaved changes are lost.
@Suite("Unsaved changes")
@MainActor
struct UnsavedChangesTests {
    @Test func onlyChangedNonEmptySQLIsUnsaved() {
        #expect(!QueryEditorState.hasUnsavedChanges(sql: "SELECT 1", savedSQL: "SELECT 1"))
        #expect(QueryEditorState.hasUnsavedChanges(sql: "SELECT 2", savedSQL: "SELECT 1"))
        #expect(QueryEditorState.hasUnsavedChanges(sql: "SELECT 1", savedSQL: ""))
        #expect(!QueryEditorState.hasUnsavedChanges(sql: "  \n", savedSQL: "SELECT 1"))
    }

    @Test func alertNamesTheTabAndWhereSaveGoes() {
        let plain = UnsavedChangesAlert.texts(tab: "Query 1", bookmark: nil)
        #expect(plain.title == "Do you want to save the changes to \u{201C}Query 1\u{201D}?")
        #expect(plain.message.contains("bookmark in the project"))
        #expect(UnsavedChangesAlert.texts(tab: "Query 1", bookmark: "Daily").message.contains("\u{201C}Daily\u{201D}"))
        #expect(UnsavedChangesAlert.structureTexts(tab: "orders").title == "Do you want to apply the changes to \u{201C}orders\u{201D}?")
        #expect(UnsavedChangesAlert.severalTexts(["A", "B", "C"]).title == "3 tabs have unsaved changes")
    }
}
