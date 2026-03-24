import SQLServerKit
import Foundation

public struct SQLServerColumnInference: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public var dataType: String
    public var isNullable: Bool
    
    public init(name: String, dataType: String, isNullable: Bool) {
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
    }
}

extension SQLServerBulkCopyClient {
    /// Infers column types from a sample of string-based rows.
    public func inferSchema(headers: [String], sampleRows: [[String]]) -> [SQLServerColumnInference] {
        var inferences: [SQLServerColumnInference] = []
        
        for (index, header) in headers.enumerated() {
            let values = sampleRows.compactMap { $0.indices.contains(index) ? $0[index] : nil }
            let inferredType = inferType(for: values)
            inferences.append(SQLServerColumnInference(name: header, dataType: inferredType, isNullable: true))
        }
        
        return inferences
    }
    
    private func inferType(for values: [String]) -> String {
        if values.isEmpty { return "NVARCHAR(50)" }
        
        var canBeInt = true
        var canBeBigInt = true
        var canBeFloat = true
        var canBeDate = true
        var maxLen = 0
        
        let dateFormatter = ISO8601DateFormatter()
        
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            maxLen = max(maxLen, trimmed.count)
            
            if canBeInt && Int32(trimmed) == nil { canBeInt = false }
            if canBeBigInt && Int64(trimmed) == nil { canBeBigInt = false }
            if canBeFloat && Double(trimmed) == nil { canBeFloat = false }
            if canBeDate && dateFormatter.date(from: trimmed) == nil { canBeDate = false }
        }
        
        if canBeInt { return "INT" }
        if canBeBigInt { return "BIGINT" }
        if canBeFloat { return "FLOAT" }
        if canBeDate { return "DATETIME2" }
        
        if maxLen > 4000 { return "NVARCHAR(MAX)" }
        let roundedLen = ((maxLen / 50) + 1) * 50
        return "NVARCHAR(\(roundedLen))"
    }
    
    /// Generates a CREATE TABLE statement from inferences.
    public func generateCreateTableSQL(schema: String, table: String, columns: [SQLServerColumnInference]) -> String {
        let cols = columns.map { col in
            "[\(col.name)] \(col.dataType) \(col.isNullable ? "NULL" : "NOT NULL")"
        }.joined(separator: ",\n    ")
        
        return "CREATE TABLE [\(schema)].[\(table)] (\n    \(cols)\n);"
    }
}
