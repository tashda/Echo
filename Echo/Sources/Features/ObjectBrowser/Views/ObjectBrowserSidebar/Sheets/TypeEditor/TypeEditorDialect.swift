import Foundation

protocol TypeEditorDialect: Sendable {
    func loadMetadata(session: any DatabaseSession, schema: String, name: String, category: TypeCategory) async throws -> TypeEditorMetadata
    func generateSQL(context: TypeEditorSQLContext) -> String
    func quoteIdentifier(_ identifier: String) -> String

    var supportsComposite: Bool { get }
    var supportsEnum: Bool { get }
    var supportsRange: Bool { get }
    var supportsDomain: Bool { get }
    var supportsOwnership: Bool { get }
    var supportsComments: Bool { get }
}

struct TypeEditorMetadata: Sendable {
    var name: String
    var owner: String
    var description: String
    var attributes: [TypeAttributeDraft]
    var enumValues: [EnumValueDraft]
    var subtype: String
    var subtypeOpClass: String
    var collation: String
    var baseDataType: String
    var defaultValue: String
    var isNotNull: Bool
    var domainConstraints: [DomainConstraintDraft]
}

struct TypeEditorSQLContext: Sendable {
    var schema: String
    var name: String
    var owner: String
    var description: String
    var category: TypeCategory
    var isEditing: Bool
    var attributes: [TypeAttributeDraft]
    var enumValues: [EnumValueDraft]
    var subtype: String
    var subtypeOpClass: String
    var collation: String
    var baseDataType: String
    var defaultValue: String
    var isNotNull: Bool
    var domainConstraints: [DomainConstraintDraft]
}
