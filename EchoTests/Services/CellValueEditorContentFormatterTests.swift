import Testing
@testable import Echo

@Suite("CellValueEditorContentFormatter")
struct CellValueEditorContentFormatterTests {
    @Test func prettyPrintsValidJSON() {
        let content = CellValueInspectorContent(
            columnName: "payload",
            dataType: "json",
            rawValue: "{\"b\":2,\"a\":1}",
            valueKind: .json
        )

        let output = CellValueEditorContentFormatter.displayValue(for: content)

        #expect(output.contains("\n"))
        #expect(output.contains("\"a\""))
        #expect(output.contains("\"b\""))
    }

    @Test func leavesInvalidJSONUntouched() {
        let content = CellValueInspectorContent(
            columnName: "payload",
            dataType: "json",
            rawValue: "{invalid}",
            valueKind: .json
        )

        #expect(CellValueEditorContentFormatter.displayValue(for: content) == "{invalid}")
    }

    @Test func usesKindSpecificFileExtensions() {
        let json = CellValueInspectorContent(columnName: "payload", dataType: "json", rawValue: "{}", valueKind: .json)
        let binary = CellValueInspectorContent(columnName: "blob", dataType: "blob", rawValue: "0101", valueKind: .binary)
        let text = CellValueInspectorContent(columnName: "note", dataType: "text", rawValue: "hello", valueKind: .text)

        #expect(CellValueEditorContentFormatter.suggestedFileExtension(for: json) == "json")
        #expect(CellValueEditorContentFormatter.suggestedFileExtension(for: binary) == "bin")
        #expect(CellValueEditorContentFormatter.suggestedFileExtension(for: text) == "txt")
    }

    @Test func sanitizesSuggestedFileNames() {
        let content = CellValueInspectorContent(
            columnName: "display name/value",
            dataType: "text",
            rawValue: "hello",
            valueKind: .text
        )

        #expect(CellValueEditorContentFormatter.suggestedFileName(for: content) == "display-name-value.txt")
    }
}
