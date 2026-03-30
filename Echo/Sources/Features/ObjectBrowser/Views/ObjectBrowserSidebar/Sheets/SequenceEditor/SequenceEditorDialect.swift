import Foundation

protocol SequenceEditorDialect: Sendable {
    func loadMetadata(session: any DatabaseSession, schema: String, name: String) async throws -> SequenceEditorMetadata
    func generateSQL(context: SequenceEditorSQLContext) -> String
    func quoteIdentifier(_ identifier: String) -> String

    var supportsOwnership: Bool { get }
    var supportsOwnedBy: Bool { get }
    var supportsCache: Bool { get }
    var supportsComments: Bool { get }
}

struct SequenceEditorMetadata: Sendable {
    var name: String
    var startWith: String
    var incrementBy: String
    var minValue: String
    var maxValue: String
    var cache: String
    var cycle: Bool
    var owner: String
    var ownedBy: String
    var lastValue: String
    var description: String
}

struct SequenceEditorSQLContext: Sendable {
    var schema: String
    var name: String
    var startWith: String
    var incrementBy: String
    var minValue: String
    var maxValue: String
    var cache: String
    var cycle: Bool
    var owner: String
    var description: String
    var isEditing: Bool
}
