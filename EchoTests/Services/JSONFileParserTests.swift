import Foundation
import Testing
@testable import Echo

@Suite("JSONFileParser")
struct JSONFileParserTests {
    @Test func parsesArrayOfObjectsIntoHeadersAndRows() async throws {
        let url = try temporaryJSONFile(contents: """
        [
          { "id": 1, "name": "Alice" },
          { "id": 2, "name": "Bob", "active": true }
        ]
        """)

        let result = try await JSONFileParser.parse(url: url)

        #expect(result.headers == ["id", "name", "active"])
        #expect(result.totalRowCount == 2)
        #expect(result.rows[0] == ["1", "Alice", ""])
        #expect(result.rows[1] == ["2", "Bob", "1"])
    }

    @Test func serializesNestedValuesAsJSONStrings() async throws {
        let url = try temporaryJSONFile(contents: """
        [
          { "id": 1, "meta": { "city": "Copenhagen" }, "tags": ["mysql", "echo"] }
        ]
        """)

        let result = try await JSONFileParser.parse(url: url)

        #expect(result.rows[0][1] == #"{"city":"Copenhagen"}"#)
        #expect(result.rows[0][2] == #"["mysql","echo"]"#)
    }

    @Test func rejectsNonArrayTopLevelJSON() async throws {
        let url = try temporaryJSONFile(contents: #"{ "id": 1 }"#)

        await #expect(throws: JSONParseError.invalidTopLevel) {
            _ = try await JSONFileParser.parse(url: url)
        }
    }

    private func temporaryJSONFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
