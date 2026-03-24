import SQLServerKit
import Foundation

/// A recommendation for a missing index, derived from SQL Server DMVs.
public struct SQLServerMissingIndexRecommendation: Sendable, Equatable, Identifiable {
    public var id: Int { indexHandle }

    /// Internal SQL Server handle for this missing index group.
    public let indexHandle: Int
    /// Database name where the index is recommended.
    public let databaseName: String
    /// Schema name of the table.
    public let schemaName: String
    /// Table name that would benefit from the index.
    public let tableName: String
    /// Potential improvement in query cost if the index is created (0-100).
    public let avgTotalUserCost: Double
    /// Number of times the index would have been used by user queries.
    public let userSeeks: Int
    /// Number of times the index would have been used by user scans.
    public let userScans: Int
    /// Columns that should be included in the index key as equality predicates.
    public let equalityColumns: [String]
    /// Columns that should be included in the index key as inequality predicates.
    public let inequalityColumns: [String]
    /// Non-key columns that should be included in the index.
    public let includedColumns: [String]

    public init(
        indexHandle: Int,
        databaseName: String,
        schemaName: String,
        tableName: String,
        avgTotalUserCost: Double,
        userSeeks: Int,
        userScans: Int,
        equalityColumns: [String],
        inequalityColumns: [String],
        includedColumns: [String]
    ) {
        self.indexHandle = indexHandle
        self.databaseName = databaseName
        self.schemaName = schemaName
        self.tableName = tableName
        self.avgTotalUserCost = avgTotalUserCost
        self.userSeeks = userSeeks
        self.userScans = userScans
        self.equalityColumns = equalityColumns
        self.inequalityColumns = inequalityColumns
        self.includedColumns = includedColumns
    }
}
