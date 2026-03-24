import Foundation
import SQLServerKit

// MARK: - Window Value

struct DatabaseEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let databaseName: String
}

// MARK: - Pages

enum DatabaseEditorPage: String, Hashable, CaseIterable, Identifiable {
    // Shared
    case general
    // MSSQL
    case files
    case filegroups
    case options
    case scopedConfigurations
    case queryStore
    case mirroring
    case logShipping
    // PostgreSQL
    case definition
    case parameters
    case security
    case defaultPrivileges
    case statistics
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .files: "Files"
        case .filegroups: "Filegroups"
        case .options: "Options"
        case .scopedConfigurations: "Scoped Configurations"
        case .queryStore: "Query Store"
        case .mirroring: "Mirroring"
        case .logShipping: "Log Shipping"
        case .definition: "Definition"
        case .parameters: "Parameters"
        case .security: "Security"
        case .defaultPrivileges: "Default Privileges"
        case .statistics: "Statistics"
        case .sql: "SQL"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .files: "doc"
        case .filegroups: "folder"
        case .options: "gearshape"
        case .scopedConfigurations: "slider.horizontal.3"
        case .queryStore: "chart.bar.xaxis"
        case .mirroring: "arrow.left.arrow.right"
        case .logShipping: "shippingbox"
        case .definition: "text.book.closed"
        case .parameters: "slider.horizontal.3"
        case .security: "lock.shield"
        case .defaultPrivileges: "person.badge.key"
        case .statistics: "chart.bar"
        case .sql: "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - File Editing State Types

enum FileMaxSizeType: Hashable {
    case unlimited
    case mb
}

enum FileGrowthType: Hashable {
    case mb
    case percent
    case none
}
