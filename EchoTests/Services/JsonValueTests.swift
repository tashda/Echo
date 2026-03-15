import Foundation
import Testing
@testable import Echo

@Suite("JsonValue Parsing")
struct JsonValueParsingTests {

    // MARK: - Primitive Parsing

    @Test func parseString() throws {
        let value = try JsonValue.parse(from: "\"hello\"")
        #expect(value == .string("hello"))
    }

    @Test func parseNumber() throws {
        let value = try JsonValue.parse(from: "42")
        #expect(value == .number("42"))
    }

    @Test func parseFloat() throws {
        let value = try JsonValue.parse(from: "3.14")
        #expect(value == .number("3.14"))
    }

    @Test func parseBoolTrue() throws {
        let value = try JsonValue.parse(from: "true")
        #expect(value == .bool(true))
    }

    @Test func parseBoolFalse() throws {
        let value = try JsonValue.parse(from: "false")
        #expect(value == .bool(false))
    }

    @Test func parseNull() throws {
        let value = try JsonValue.parse(from: "null")
        #expect(value == .null)
    }

    // MARK: - Container Parsing

    @Test func parseEmptyObject() throws {
        let value = try JsonValue.parse(from: "{}")
        #expect(value == .object([]))
    }

    @Test func parseEmptyArray() throws {
        let value = try JsonValue.parse(from: "[]")
        #expect(value == .array([]))
    }

    @Test func parseSimpleObject() throws {
        let value = try JsonValue.parse(from: "{\"name\": \"Alice\", \"age\": 30}")
        guard case .object(let entries) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(entries.count == 2)
        // Keys are sorted
        #expect(entries[0].key == "age")
        #expect(entries[1].key == "name")
    }

    @Test func parseArray() throws {
        let value = try JsonValue.parse(from: "[1, 2, 3]")
        guard case .array(let values) = value else {
            Issue.record("Expected array")
            return
        }
        #expect(values.count == 3)
    }

    @Test func parseNestedStructure() throws {
        let json = """
        {"users": [{"name": "Alice"}, {"name": "Bob"}]}
        """
        let value = try JsonValue.parse(from: json)
        guard case .object(let entries) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(entries.count == 1)
        guard case .array(let users) = entries[0].value else {
            Issue.record("Expected array")
            return
        }
        #expect(users.count == 2)
    }

    // MARK: - Error Cases

    @Test func parseInvalidJSONThrows() {
        #expect(throws: Error.self) {
            _ = try JsonValue.parse(from: "{invalid")
        }
    }

    // MARK: - Properties

    @Test func kindReturnsCorrectType() throws {
        #expect(JsonValue.string("a").kind == .string)
        #expect(JsonValue.number("1").kind == .number)
        #expect(JsonValue.bool(true).kind == .boolean)
        #expect(JsonValue.null.kind == .null)
        #expect(JsonValue.object([]).kind == .object)
        #expect(JsonValue.array([]).kind == .array)
    }

    @Test func isContainer() {
        #expect(JsonValue.object([]).isContainer)
        #expect(JsonValue.array([]).isContainer)
        #expect(!JsonValue.string("a").isContainer)
        #expect(!JsonValue.number("1").isContainer)
        #expect(!JsonValue.bool(true).isContainer)
        #expect(!JsonValue.null.isContainer)
    }

    @Test func childCount() {
        let entries = [
            JsonValue.ObjectEntry(key: "a", value: .string("1")),
            JsonValue.ObjectEntry(key: "b", value: .string("2")),
        ]
        #expect(JsonValue.object(entries).childCount == 2)
        #expect(JsonValue.array([.null, .null, .null]).childCount == 3)
        #expect(JsonValue.string("hello").childCount == 0)
    }

    @Test func summary() {
        #expect(JsonValue.object([]).summary == "0 keys")
        let oneEntry = [JsonValue.ObjectEntry(key: "a", value: .null)]
        #expect(JsonValue.object(oneEntry).summary == "1 key")
        #expect(JsonValue.array([.null]).summary == "1 item")
        #expect(JsonValue.array([.null, .null]).summary == "2 items")
        #expect(JsonValue.string("hello").summary == "hello")
        #expect(JsonValue.number("42").summary == "42")
        #expect(JsonValue.bool(true).summary == "true")
        #expect(JsonValue.bool(false).summary == "false")
        #expect(JsonValue.null.summary == "null")
    }
}

@Suite("JsonOutlineNode")
struct JsonOutlineNodeTests {

    @Test func toOutlineNodeCreatesTree() throws {
        let json = """
        {"name": "Alice", "scores": [10, 20]}
        """
        let value = try JsonValue.parse(from: json)
        let node = value.toOutlineNode()
        #expect(node.hasChildren)
        #expect(node.children.count == 2)
    }

    @Test func outlineNodeTitle() {
        let node = JsonOutlineNode(
            id: UUID(),
            key: .property("name", index: 0),
            value: .string("Alice"),
            children: []
        )
        #expect(node.title == "name")
    }

    @Test func outlineNodeRootTitle() {
        let node = JsonOutlineNode(
            id: UUID(),
            key: .root,
            value: .object([]),
            children: []
        )
        #expect(node.title == "Object")
    }

    @Test func jsonPathProperty() {
        let node = JsonOutlineNode(
            id: UUID(),
            key: .property("name", index: 0),
            value: .string("Alice"),
            children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$.name")
    }

    @Test func jsonPathIndex() {
        let node = JsonOutlineNode(
            id: UUID(),
            key: .index(2),
            value: .number("42"),
            children: []
        )
        #expect(node.jsonPath(parentPath: "$.items") == "$.items[2]")
    }

    @Test func jsonPathSpecialCharacters() {
        let node = JsonOutlineNode(
            id: UUID(),
            key: .property("my.key", index: 0),
            value: .string("val"),
            children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$['my.key']")
    }

    @Test func jsonPathWithSpaces() {
        let node = JsonOutlineNode(
            id: UUID(),
            key: .property("my key", index: 0),
            value: .string("val"),
            children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$['my key']")
    }

    @Test func jsonPathWithDash() {
        let node = JsonOutlineNode(
            id: UUID(),
            key: .property("my-key", index: 0),
            value: .string("val"),
            children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$['my-key']")
    }

    @Test func leafNodeHasNoChildren() {
        let node = JsonValue.string("hello").toOutlineNode()
        #expect(!node.hasChildren)
        #expect(node.children.isEmpty)
    }
}

@Suite("JsonDetailRow")
struct JsonDetailRowTests {

    @Test func objectMakesDetailRows() {
        let entries = [
            JsonValue.ObjectEntry(key: "a", value: .string("1")),
            JsonValue.ObjectEntry(key: "b", value: .number("2")),
        ]
        let rows = JsonValue.object(entries).makeDetailRows()
        #expect(rows.count == 2)
        #expect(rows[0].key == .property("a", index: 0))
        #expect(rows[1].key == .property("b", index: 1))
    }

    @Test func arrayMakesDetailRows() {
        let values: [JsonValue] = [.string("a"), .string("b")]
        let rows = JsonValue.array(values).makeDetailRows()
        #expect(rows.count == 2)
        #expect(rows[0].key == .index(0))
        #expect(rows[1].key == .index(1))
    }

    @Test func leafMakesNoDetailRows() {
        #expect(JsonValue.string("hello").makeDetailRows().isEmpty)
        #expect(JsonValue.null.makeDetailRows().isEmpty)
    }

    @Test func detailRowKeyDisplayTitle() {
        #expect(JsonDetailRow.Key.property("name", index: 0).displayTitle == "name")
        #expect(JsonDetailRow.Key.index(3).displayTitle == "#3")
    }

    @Test func detailRowKeyBreadcrumbTitle() {
        #expect(JsonDetailRow.Key.property("name", index: 0).breadcrumbTitle == "name")
        #expect(JsonDetailRow.Key.index(3).breadcrumbTitle == "[3]")
    }
}
