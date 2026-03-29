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

        #expect(Set(result.headers) == Set(["id", "name", "active"]))
        #expect(result.totalRowCount == 2)
        // Map rows by header to be order-independent
        let headerIndex = Dictionary(uniqueKeysWithValues: result.headers.enumerated().map { ($1, $0) })
        let row0 = result.rows[0]
        let row1 = result.rows[1]
        #expect(row0[headerIndex["id"]!] == "1")
        #expect(row0[headerIndex["name"]!] == "Alice")
        #expect(row0[headerIndex["active"]!] == "")
        #expect(row1[headerIndex["id"]!] == "2")
        #expect(row1[headerIndex["name"]!] == "Bob")
        #expect(row1[headerIndex["active"]!] == "1")
    }

    @Test func serializesNestedValuesAsJSONStrings() async throws {
        let url = try temporaryJSONFile(contents: """
        [
          { "id": 1, "meta": { "city": "Copenhagen" }, "tags": ["mysql", "echo"] }
        ]
        """)

        let result = try await JSONFileParser.parse(url: url)

        let hdrIdx = Dictionary(uniqueKeysWithValues: result.headers.enumerated().map { ($1, $0) })
        #expect(result.rows[0][hdrIdx["meta"]!] == #"{"city":"Copenhagen"}"#)
        #expect(result.rows[0][hdrIdx["tags"]!] == #"["mysql","echo"]"#)
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
