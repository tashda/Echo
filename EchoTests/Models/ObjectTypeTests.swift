import Testing
import Foundation
@testable import Echo

@Suite("ObjectType - New Cases")
struct ObjectTypeNewCasesTests {
    @Test func sequencePluralDisplayName() {
        #expect(SchemaObjectInfo.ObjectType.sequence.pluralDisplayName == "Sequences")
    }

    @Test func typePluralDisplayName() {
        #expect(SchemaObjectInfo.ObjectType.type.pluralDisplayName == "Types")
    }

    @Test func synonymPluralDisplayName() {
        #expect(SchemaObjectInfo.ObjectType.synonym.pluralDisplayName == "Synonyms")
    }

    @Test func sequenceSystemImage() {
        #expect(SchemaObjectInfo.ObjectType.sequence.systemImage == "number")
    }

    @Test func typeSystemImage() {
        #expect(SchemaObjectInfo.ObjectType.type.systemImage == "t.square")
    }

    @Test func synonymSystemImage() {
        #expect(SchemaObjectInfo.ObjectType.synonym.systemImage == "arrow.triangle.branch")
    }

    @Test func sequenceCodableRoundTrip() throws {
        let obj = SchemaObjectInfo(name: "my_seq", schema: "public", type: .sequence)
        let data = try JSONEncoder().encode(obj)
        let decoded = try JSONDecoder().decode(SchemaObjectInfo.self, from: data)
        #expect(decoded.type == .sequence)
        #expect(decoded.name == "my_seq")
    }

    @Test func typeCodableRoundTrip() throws {
        let obj = SchemaObjectInfo(name: "my_enum", schema: "public", type: .type, comment: "enum")
        let data = try JSONEncoder().encode(obj)
        let decoded = try JSONDecoder().decode(SchemaObjectInfo.self, from: data)
        #expect(decoded.type == .type)
        #expect(decoded.comment == "enum")
    }

    @Test func synonymCodableRoundTrip() throws {
        let obj = SchemaObjectInfo(name: "my_syn", schema: "dbo", type: .synonym)
        let data = try JSONEncoder().encode(obj)
        let decoded = try JSONDecoder().decode(SchemaObjectInfo.self, from: data)
        #expect(decoded.type == .synonym)
    }

    @Test func postgresSupportsSequencesTypesAndProcedures() {
        let supported = SchemaObjectInfo.ObjectType.supported(for: .postgresql)
        #expect(supported.contains(.sequence))
        #expect(supported.contains(.type))
        #expect(supported.contains(.procedure))
    }

    @Test func mssqlSupportsSynonyms() {
        let supported = SchemaObjectInfo.ObjectType.supported(for: .microsoftSQL)
        #expect(supported.contains(.synonym))
    }

    @Test func sqliteDoesNotSupportNewTypes() {
        let supported = SchemaObjectInfo.ObjectType.supported(for: .sqlite)
        #expect(!supported.contains(.sequence))
        #expect(!supported.contains(.type))
        #expect(!supported.contains(.synonym))
    }
}
