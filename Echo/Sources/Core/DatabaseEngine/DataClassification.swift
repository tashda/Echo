import Foundation

/// Sensitivity rank for data classification, mirroring SQL Server's sensitivity ranking.
public enum SensitivityRank: Int, Sendable, Codable, Comparable {
    case notDefined = -1
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: SensitivityRank, rhs: SensitivityRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .notDefined: "Not Defined"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}

/// A sensitivity label attached to a classified column.
public struct SensitivityLabel: Sendable, Codable, Hashable {
    let name: String
    let id: String
}

/// An information type describing the kind of sensitive data in a column.
public struct InformationType: Sendable, Codable, Hashable {
    let name: String
    let id: String
}

/// Classification metadata for a single column in the result set.
public struct ColumnSensitivity: Sendable, Codable {
    let label: SensitivityLabel?
    let informationType: InformationType?
    let rank: SensitivityRank?

    /// The effective rank, falling back to `.notDefined` when absent.
    var effectiveRank: SensitivityRank {
        rank ?? .notDefined
    }

    /// A concise display string combining label and information type.
    var summary: String {
        let parts = [label?.name, informationType?.name].compactMap { $0 }
        return parts.isEmpty ? "Classified" : parts.joined(separator: " / ")
    }
}

/// Full sensitivity classification for a query result set.
public struct DataClassification: Sendable {
    let labels: [SensitivityLabel]
    let informationTypes: [InformationType]
    let columns: [Int: ColumnSensitivity]
    let overallRank: SensitivityRank?

    /// Returns the classification for a column at the given index, if any.
    func classification(forColumnAt index: Int) -> ColumnSensitivity? {
        columns[index]
    }

    /// Whether any column in the result set has classification data.
    var hasClassifiedColumns: Bool {
        !columns.isEmpty
    }
}
