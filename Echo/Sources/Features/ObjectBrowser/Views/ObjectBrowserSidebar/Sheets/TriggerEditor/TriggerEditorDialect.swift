import Foundation

protocol TriggerEditorDialect: Sendable {
    func loadMetadata(session: any DatabaseSession, schema: String, table: String, name: String) async throws -> TriggerEditorMetadata
    func generateSQL(context: TriggerEditorSQLContext) -> String
    func quoteIdentifier(_ identifier: String) -> String

    var supportsTruncateEvent: Bool { get }
    var supportsWhenCondition: Bool { get }
    var supportsInsteadOfTiming: Bool { get }
    var supportsForEach: Bool { get }
    var supportsFunctionReference: Bool { get }
    var supportsEnableDisable: Bool { get }
    var supportsComments: Bool { get }
}

struct TriggerEditorMetadata: Sendable {
    var name: String
    var functionName: String
    var timing: TriggerTiming
    var forEach: TriggerForEach
    var onInsert: Bool
    var onUpdate: Bool
    var onDelete: Bool
    var onTruncate: Bool
    var whenCondition: String
    var isEnabled: Bool
    var description: String
}

struct TriggerEditorSQLContext: Sendable {
    var schema: String
    var table: String
    var name: String
    var functionName: String
    var timing: TriggerTiming
    var forEach: TriggerForEach
    var onInsert: Bool
    var onUpdate: Bool
    var onDelete: Bool
    var onTruncate: Bool
    var whenCondition: String
    var isEnabled: Bool
    var description: String
    var isEditing: Bool
}
