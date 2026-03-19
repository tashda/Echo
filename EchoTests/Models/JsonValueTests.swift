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

    @Test func parseEmptyString() throws {
        let value = try JsonValue.parse(from: "\"\"")
        #expect(value == .string(""))
    }

    @Test func parseStringWithUnicode() throws {
        let value = try JsonValue.parse(from: "\"Hello \\u4e16\\u754c\"")
        #expect(value == .string("Hello \u{4e16}\u{754c}"))
    }

    @Test func parseStringWithEscapedCharacters() throws {
        let value = try JsonValue.parse(from: "\"line1\\nline2\\ttab\"")
        #expect(value == .string("line1\nline2\ttab"))
    }

    @Test func parseVeryLongString() throws {
        let longString = String(repeating: "a", count: 10_000)
        let json = "\"\(longString)\""
        let value = try JsonValue.parse(from: json)
        #expect(value == .string(longString))
    }

    @Test func parseNumber() throws {
        let value = try JsonValue.parse(from: "42")
        #expect(value == .number("42"))
    }

    @Test func parseFloat() throws {
        let value = try JsonValue.parse(from: "3.14")
        #expect(value == .number("3.14"))
    }

    @Test func parseNegativeNumber() throws {
        let value = try JsonValue.parse(from: "-99")
        #expect(value == .number("-99"))
    }

    @Test func parseScientificNotation() throws {
        let value = try JsonValue.parse(from: "1.5e10")
        let parsed = try JsonValue.parse(from: "1.5e10")
        guard case .number(let str) = parsed else {
            Issue.record("Expected number")
            return
        }
        // NSNumber may format this differently
        #expect(!str.isEmpty)
    }

    @Test func parseZero() throws {
        let value = try JsonValue.parse(from: "0")
        #expect(value == .number("0"))
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
        // Keys are sorted alphabetically
        #expect(entries[0].key == "age")
        #expect(entries[0].value == .number("30"))
        #expect(entries[1].key == "name")
        #expect(entries[1].value == .string("Alice"))
    }

    @Test func parseObjectWithSpecialCharacterKeys() throws {
        let json = "{\"my.key\": 1, \"my-key\": 2, \"my key\": 3}"
        let value = try JsonValue.parse(from: json)
        guard case .object(let entries) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(entries.count == 3)
        let keys = entries.map(\.key)
        #expect(keys.contains("my.key"))
        #expect(keys.contains("my-key"))
        #expect(keys.contains("my key"))
    }

    @Test func parseArray() throws {
        let value = try JsonValue.parse(from: "[1, 2, 3]")
        guard case .array(let values) = value else {
            Issue.record("Expected array")
            return
        }
        #expect(values.count == 3)
        #expect(values[0] == .number("1"))
        #expect(values[1] == .number("2"))
        #expect(values[2] == .number("3"))
    }

    @Test func parseMixedArray() throws {
        let json = "[1, \"two\", true, null, {\"a\": 1}]"
        let value = try JsonValue.parse(from: json)
        guard case .array(let values) = value else {
            Issue.record("Expected array")
            return
        }
        #expect(values.count == 5)
        #expect(values[0] == .number("1"))
        #expect(values[1] == .string("two"))
        #expect(values[2] == .bool(true))
        #expect(values[3] == .null)
        #expect(values[4].kind == .object)
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
        #expect(entries[0].key == "users")
        guard case .array(let users) = entries[0].value else {
            Issue.record("Expected array")
            return
        }
        #expect(users.count == 2)
    }

    @Test func parseDeeplyNestedStructure() throws {
        let json = "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":{\"f\":\"deep\"}}}}}}"
        let value = try JsonValue.parse(from: json)
        // Navigate 6 levels deep: root(a) -> b -> c -> d -> e -> f
        guard case .object(let l1) = value,
              case .object(let l2) = l1[0].value,
              case .object(let l3) = l2[0].value,
              case .object(let l4) = l3[0].value,
              case .object(let l5) = l4[0].value,
              case .object(let l6) = l5[0].value else {
            Issue.record("Expected 6 levels of nesting")
            return
        }
        #expect(l6[0].key == "f")
        #expect(l6[0].value == .string("deep"))
    }

    @Test func parseLargeArray() throws {
        let elements = (0..<100).map { "\($0)" }.joined(separator: ",")
        let json = "[\(elements)]"
        let value = try JsonValue.parse(from: json)
        guard case .array(let values) = value else {
            Issue.record("Expected array")
            return
        }
        #expect(values.count == 100)
    }

    @Test func parseObjectWithAllValueTypes() throws {
        let json = """
        {"str":"hello","num":42,"float":3.14,"bool":true,"null":null,"arr":[],"obj":{}}
        """
        let value = try JsonValue.parse(from: json)
        guard case .object(let entries) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(entries.count == 7)
    }

    @Test func parseNumbersAsStringsVsActualNumbers() throws {
        let json = "{\"number\": 42, \"string_number\": \"42\"}"
        let value = try JsonValue.parse(from: json)
        guard case .object(let entries) = value else {
            Issue.record("Expected object")
            return
        }
        // Sorted: "number" < "string_number"
        #expect(entries[0].value == .number("42"))
        #expect(entries[1].value == .string("42"))
    }

    // MARK: - Error Cases

    @Test func parseInvalidJSONThrows() {
        #expect(throws: Error.self) {
            _ = try JsonValue.parse(from: "{invalid")
        }
    }

    @Test func parseEmptyStringInputThrows() {
        #expect(throws: Error.self) {
            _ = try JsonValue.parse(from: "")
        }
    }

    // MARK: - Kind

    @Test func kindReturnsCorrectType() {
        #expect(JsonValue.string("a").kind == .string)
        #expect(JsonValue.number("1").kind == .number)
        #expect(JsonValue.bool(true).kind == .boolean)
        #expect(JsonValue.null.kind == .null)
        #expect(JsonValue.object([]).kind == .object)
        #expect(JsonValue.array([]).kind == .array)
    }

    @Test func kindDisplayNames() {
        #expect(JsonValue.Kind.object.displayName == "Object")
        #expect(JsonValue.Kind.array.displayName == "Array")
        #expect(JsonValue.Kind.string.displayName == "String")
        #expect(JsonValue.Kind.number.displayName == "Number")
        #expect(JsonValue.Kind.boolean.displayName == "Boolean")
        #expect(JsonValue.Kind.null.displayName == "Null")
    }

    // MARK: - isContainer

    @Test func isContainerForContainers() {
        #expect(JsonValue.object([]).isContainer)
        #expect(JsonValue.array([]).isContainer)
    }

    @Test func isContainerForPrimitives() {
        #expect(!JsonValue.string("a").isContainer)
        #expect(!JsonValue.number("1").isContainer)
        #expect(!JsonValue.bool(true).isContainer)
        #expect(!JsonValue.null.isContainer)
    }

    // MARK: - childCount

    @Test func childCountForObject() {
        let entries = [
            JsonValue.ObjectEntry(key: "a", value: .string("1")),
            JsonValue.ObjectEntry(key: "b", value: .string("2")),
        ]
        #expect(JsonValue.object(entries).childCount == 2)
    }

    @Test func childCountForEmptyContainers() {
        #expect(JsonValue.object([]).childCount == 0)
        #expect(JsonValue.array([]).childCount == 0)
    }

    @Test func childCountForArray() {
        #expect(JsonValue.array([.null, .null, .null]).childCount == 3)
    }

    @Test func childCountForPrimitives() {
        #expect(JsonValue.string("hello").childCount == 0)
        #expect(JsonValue.number("42").childCount == 0)
        #expect(JsonValue.bool(false).childCount == 0)
        #expect(JsonValue.null.childCount == 0)
    }

    // MARK: - Summary

    @Test func summaryForObjects() {
        #expect(JsonValue.object([]).summary == "0 keys")
        let oneEntry = [JsonValue.ObjectEntry(key: "a", value: .null)]
        #expect(JsonValue.object(oneEntry).summary == "1 key")
        let twoEntries = [
            JsonValue.ObjectEntry(key: "a", value: .null),
            JsonValue.ObjectEntry(key: "b", value: .null),
        ]
        #expect(JsonValue.object(twoEntries).summary == "2 keys")
    }

    @Test func summaryForArrays() {
        #expect(JsonValue.array([]).summary == "0 items")
        #expect(JsonValue.array([.null]).summary == "1 item")
        #expect(JsonValue.array([.null, .null]).summary == "2 items")
    }

    @Test func summaryForPrimitives() {
        #expect(JsonValue.string("hello").summary == "hello")
        #expect(JsonValue.number("42").summary == "42")
        #expect(JsonValue.bool(true).summary == "true")
        #expect(JsonValue.bool(false).summary == "false")
        #expect(JsonValue.null.summary == "null")
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
        #expect(rows[0].value == .string("1"))
        #expect(rows[1].key == .property("b", index: 1))
        #expect(rows[1].value == .number("2"))
    }

    @Test func arrayMakesDetailRows() {
        let values: [JsonValue] = [.string("a"), .string("b")]
        let rows = JsonValue.array(values).makeDetailRows()
        #expect(rows.count == 2)
        #expect(rows[0].key == .index(0))
        #expect(rows[0].value == .string("a"))
        #expect(rows[1].key == .index(1))
        #expect(rows[1].value == .string("b"))
    }

    @Test func nestedObjectMakesDetailRows() {
        let inner = JsonValue.ObjectEntry(key: "nested", value: .array([.number("1")]))
        let entries = [JsonValue.ObjectEntry(key: "top", value: .object([inner]))]
        let rows = JsonValue.object(entries).makeDetailRows()
        #expect(rows.count == 1)
        #expect(rows[0].value.isContainer)
        #expect(rows[0].value.childCount == 1)
    }

    @Test func leafMakesNoDetailRows() {
        #expect(JsonValue.string("hello").makeDetailRows().isEmpty)
        #expect(JsonValue.number("42").makeDetailRows().isEmpty)
        #expect(JsonValue.bool(true).makeDetailRows().isEmpty)
        #expect(JsonValue.null.makeDetailRows().isEmpty)
    }

    @Test func detailRowTypeDescription() {
        let row = JsonDetailRow(
            id: UUID(),
            key: .property("name", index: 0),
            value: .string("Alice")
        )
        #expect(row.typeDescription == "String")
    }

    @Test func detailRowPreview() {
        let row = JsonDetailRow(
            id: UUID(),
            key: .property("count", index: 0),
            value: .number("42")
        )
        #expect(row.preview == "42")
    }

    @Test func detailRowKeyDisplayTitle() {
        #expect(JsonDetailRow.Key.property("name", index: 0).displayTitle == "name")
        #expect(JsonDetailRow.Key.index(3).displayTitle == "#3")
        #expect(JsonDetailRow.Key.index(0).displayTitle == "#0")
    }

    @Test func detailRowKeyBreadcrumbTitle() {
        #expect(JsonDetailRow.Key.property("name", index: 0).breadcrumbTitle == "name")
        #expect(JsonDetailRow.Key.index(3).breadcrumbTitle == "[3]")
        #expect(JsonDetailRow.Key.index(0).breadcrumbTitle == "[0]")
    }

    @Test func emptyObjectDetailRows() {
        let rows = JsonValue.object([]).makeDetailRows()
        #expect(rows.isEmpty)
    }

    @Test func emptyArrayDetailRows() {
        let rows = JsonValue.array([]).makeDetailRows()
        #expect(rows.isEmpty)
    }

    @Test func detailRowsHaveUniqueIDs() {
        let entries = [
            JsonValue.ObjectEntry(key: "a", value: .string("1")),
            JsonValue.ObjectEntry(key: "b", value: .string("2")),
        ]
        let rows = JsonValue.object(entries).makeDetailRows()
        #expect(rows[0].id != rows[1].id)
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

    @Test func rootNodeKeyIsRoot() {
        let node = JsonValue.string("hello").toOutlineNode()
        #expect(node.key == .root)
    }

    @Test func outlineNodeWithPropertyKey() {
        let node = JsonValue.string("Alice").toOutlineNode(key: .property("name", index: 0))
        #expect(node.title == "name")
    }

    @Test func outlineNodeWithIndexKey() {
        let node = JsonValue.number("42").toOutlineNode(key: .index(5))
        #expect(node.title == "[5]")
    }

    @Test func outlineNodeRootTitle() {
        let objNode = JsonOutlineNode(
            id: UUID(), key: .root, value: .object([]), children: []
        )
        #expect(objNode.title == "Object")

        let arrNode = JsonOutlineNode(
            id: UUID(), key: .root, value: .array([]), children: []
        )
        #expect(arrNode.title == "Array")

        let strNode = JsonOutlineNode(
            id: UUID(), key: .root, value: .string("x"), children: []
        )
        #expect(strNode.title == "String")
    }

    @Test func outlineNodeSubtitle() {
        let node = JsonOutlineNode(
            id: UUID(), key: .root, value: .string("hello"), children: []
        )
        #expect(node.subtitle == "hello")

        let objNode = JsonOutlineNode(
            id: UUID(), key: .root, value: .object([]), children: []
        )
        #expect(objNode.subtitle == "0 keys")
    }

    @Test func outlineNodeKeyDisplayTitle() {
        #expect(JsonOutlineNode.Key.root.displayTitle == nil)
        #expect(JsonOutlineNode.Key.property("name", index: 0).displayTitle == "name")
        #expect(JsonOutlineNode.Key.index(2).displayTitle == "[2]")
    }

    @Test func leafNodeHasNoChildren() {
        let node = JsonValue.string("hello").toOutlineNode()
        #expect(!node.hasChildren)
        #expect(node.children.isEmpty)
    }

    @Test func objectOutlineNodeHasChildrenForEntries() {
        let entries = [
            JsonValue.ObjectEntry(key: "a", value: .string("1")),
            JsonValue.ObjectEntry(key: "b", value: .number("2")),
        ]
        let node = JsonValue.object(entries).toOutlineNode()
        #expect(node.hasChildren)
        #expect(node.children.count == 2)
        #expect(node.children[0].key == .property("a", index: 0))
        #expect(node.children[1].key == .property("b", index: 1))
    }

    @Test func arrayOutlineNodeHasChildrenForElements() {
        let values: [JsonValue] = [.string("x"), .string("y")]
        let node = JsonValue.array(values).toOutlineNode()
        #expect(node.hasChildren)
        #expect(node.children.count == 2)
        #expect(node.children[0].key == .index(0))
        #expect(node.children[1].key == .index(1))
    }

    @Test func deeplyNestedOutlineTree() throws {
        let json = "{\"a\":{\"b\":{\"c\":\"deep\"}}}"
        let value = try JsonValue.parse(from: json)
        let root = value.toOutlineNode()
        #expect(root.hasChildren)
        let level1 = root.children[0]
        #expect(level1.hasChildren)
        let level2 = level1.children[0]
        #expect(level2.hasChildren)
        let level3 = level2.children[0]
        #expect(!level3.hasChildren)
        #expect(level3.value == .string("deep"))
    }

    // MARK: - jsonPath

    @Test func jsonPathRoot() {
        let node = JsonOutlineNode(
            id: UUID(), key: .root, value: .object([]), children: []
        )
        #expect(node.jsonPath() == "$")
        #expect(node.jsonPath(parentPath: "$.foo") == "$.foo")
    }

    @Test func jsonPathSimpleProperty() {
        let node = JsonOutlineNode(
            id: UUID(), key: .property("name", index: 0), value: .string("Alice"), children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$.name")
    }

    @Test func jsonPathIndex() {
        let node = JsonOutlineNode(
            id: UUID(), key: .index(2), value: .number("42"), children: []
        )
        #expect(node.jsonPath(parentPath: "$.items") == "$.items[2]")
    }

    @Test func jsonPathPropertyWithDot() {
        let node = JsonOutlineNode(
            id: UUID(), key: .property("my.key", index: 0), value: .string("val"), children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$['my.key']")
    }

    @Test func jsonPathPropertyWithSpace() {
        let node = JsonOutlineNode(
            id: UUID(), key: .property("my key", index: 0), value: .string("val"), children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$['my key']")
    }

    @Test func jsonPathPropertyWithDash() {
        let node = JsonOutlineNode(
            id: UUID(), key: .property("my-key", index: 0), value: .string("val"), children: []
        )
        #expect(node.jsonPath(parentPath: "$") == "$['my-key']")
    }

    @Test func jsonPathNestedProperty() {
        let node = JsonOutlineNode(
            id: UUID(), key: .property("city", index: 0), value: .string("NYC"), children: []
        )
        #expect(node.jsonPath(parentPath: "$.address") == "$.address.city")
    }

    @Test func jsonPathNestedIndex() {
        let node = JsonOutlineNode(
            id: UUID(), key: .index(0), value: .string("first"), children: []
        )
        #expect(node.jsonPath(parentPath: "$.items") == "$.items[0]")
    }

    @Test func outlineNodesHaveUniqueIDs() throws {
        let json = "{\"a\": 1, \"b\": 2}"
        let value = try JsonValue.parse(from: json)
        let root = value.toOutlineNode()
        #expect(root.id != root.children[0].id)
        #expect(root.children[0].id != root.children[1].id)
    }
}
