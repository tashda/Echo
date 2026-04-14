import Foundation

public enum ResultGridValueKind: Sendable, Equatable {
    case text, numeric, boolean, temporal, binary, identifier, json, null
}

public enum ResultGridValueClassifier {
    private static let numericTypeTokens: Set<String> = [
        "int", "integer", "smallint", "bigint", "tinyint", "mediumint",
        "int2", "int4", "int8", "serial", "bigserial", "smallserial",
        "decimal", "numeric", "real", "float", "float4", "float8",
        "double", "doubleprecision", "money", "number",
        // MSSQL nullable/variant wire types
        "intn", "floatn", "moneyn", "smallmoney"
    ]
    private static let booleanTypeTokens: Set<String> = ["bool", "boolean", "bitn"]
    private static let temporalTypeTokens: Set<String> = [
        "date", "time", "timestamp", "datetime", "timestamptz", "timetz", "interval", "year",
        // MSSQL-specific temporal types
        "smalldatetime", "datetime2", "datetimeoffset", "datetimen"
    ]
    private static let binaryTypeTokens: Set<String> = ["bytea", "blob", "binary", "varbinary", "image", "bfile", "raw"]
    private static let jsonTypeTokens: Set<String> = ["json", "jsonb"]
    private static let identifierTypeTokens: Set<String> = ["uuid", "uniqueidentifier", "guid"]
    private static let bitBooleanExclusionTokens: Set<String> = ["varying", "var", "binary"]

    public static func kind(for column: ColumnInfo?, value: String?) -> ResultGridValueKind {
        guard value != nil else { return .null }
        guard let column else { return .text }
        return kind(for: normalizedTypeTokens(for: column.dataType))
    }

    public static func kind(forDataType dataType: String?, value: String?) -> ResultGridValueKind {
        guard value != nil else { return .null }
        guard let dataType else { return .text }
        return kind(for: normalizedTypeTokens(for: dataType))
    }

    private static func kind(for tokens: [String]) -> ResultGridValueKind {
        guard !tokens.isEmpty else { return .text }
        let tokenSet = Set(tokens)
        if !tokenSet.intersection(booleanTypeTokens).isEmpty { return .boolean }
        if tokenSet.contains("bit") && tokenSet.intersection(bitBooleanExclusionTokens).isEmpty { return .boolean }
        if !tokenSet.intersection(numericTypeTokens).isEmpty { return .numeric }
        if !tokenSet.intersection(temporalTypeTokens).isEmpty { return .temporal }
        if !tokenSet.intersection(jsonTypeTokens).isEmpty { return .json }
        if !tokenSet.intersection(identifierTypeTokens).isEmpty { return .identifier }
        if !tokenSet.intersection(binaryTypeTokens).isEmpty || (tokenSet.contains("bit") && !tokenSet.intersection(bitBooleanExclusionTokens).isEmpty) { return .binary }
        return .text
    }

    private static func normalizedTypeTokens(for rawType: String) -> [String] {
        let lowered = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let separators = CharacterSet.alphanumerics.inverted
        return lowered.components(separatedBy: separators).filter { !$0.isEmpty }
    }
}
