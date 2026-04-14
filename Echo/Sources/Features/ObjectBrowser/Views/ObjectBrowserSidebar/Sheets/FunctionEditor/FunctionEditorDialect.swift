import Foundation

/// Strategy protocol for dialect-specific function editor behavior.
protocol FunctionEditorDialect: Sendable {
    func loadMetadata(session: any DatabaseSession, schema: String, name: String) async throws -> FunctionEditorMetadata
    func generateSQL(context: FunctionEditorSQLContext) -> String
    func quoteIdentifier(_ identifier: String) -> String

    var supportsLanguage: Bool { get }
    var supportsVolatility: Bool { get }
    var supportsParallelSafety: Bool { get }
    var supportsSecurityType: Bool { get }
    var supportsStrict: Bool { get }
    var supportsCost: Bool { get }
    var supportsEstimatedRows: Bool { get }
    var supportsComments: Bool { get }
    var supportsCreateOrReplace: Bool { get }
    var defaultLanguage: String { get }
}

struct FunctionEditorMetadata: Sendable {
    var name: String
    var language: String
    var returnType: String
    var body: String
    var volatility: FunctionVolatility
    var parallelSafety: FunctionParallelSafety
    var securityType: FunctionSecurityType
    var isStrict: Bool
    var cost: String
    var estimatedRows: String
    var description: String
    var parameters: [FunctionParameterDraft]
}

struct FunctionEditorSQLContext: Sendable {
    var schema: String
    var name: String
    var language: String
    var returnType: String
    var body: String
    var volatility: FunctionVolatility
    var parallelSafety: FunctionParallelSafety
    var securityType: FunctionSecurityType
    var isStrict: Bool
    var cost: String
    var estimatedRows: String
    var description: String
    var parameters: [FunctionParameterDraft]
    var isEditing: Bool
}
