import SwiftUI
import SQLServerKit

// MARK: - Data Loading & Constants

extension DatabasePropertiesSheet {
    func loadProperties() async {
        do {
            switch session.connection.databaseType {
            case .postgresql:
                try await loadPostgresProperties()
            case .microsoftSQL:
                try await loadMSSQLProperties()
            default:
                break
            }
            isLoading = false
        } catch {
            let raw = error.localizedDescription
            // Surface user-friendly message for common Postgres errors
            if raw.contains("column") && raw.contains("does not exist") {
                errorMessage = "Some properties are unavailable on this server version."
            } else if raw.contains("permission denied") {
                errorMessage = "Insufficient permissions to read database properties."
            } else {
                errorMessage = raw
            }
            isLoading = false
        }
    }

    var compatibilityLevels: [(label: String, value: Int)] {
        [
            ("SQL Server 2022 (160)", 160),
            ("SQL Server 2019 (150)", 150),
            ("SQL Server 2017 (140)", 140),
            ("SQL Server 2016 (130)", 130),
            ("SQL Server 2014 (120)", 120),
            ("SQL Server 2012 (110)", 110),
            ("SQL Server 2008 (100)", 100),
        ]
    }
}

// MARK: - Properties Page Enum

enum PropertiesPage: String, Hashable, CaseIterable {
    // Shared
    case general
    // MSSQL
    case options
    case automatic
    case ansi
    case files
    case queryStore
    // PostgreSQL
    case definition
    case parameters
    case security
    case defaultPrivileges
    case statistics
    case sql

    var title: String {
        switch self {
        case .general: "General"
        case .options: "Options"
        case .automatic: "Automatic"
        case .ansi: "ANSI"
        case .files: "Files"
        case .queryStore: "Query Store"
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
        case .options: "gearshape"
        case .automatic: "arrow.triangle.2.circlepath"
        case .ansi: "textformat"
        case .files: "doc"
        case .queryStore: "chart.bar.xaxis"
        case .definition: "text.book.closed"
        case .parameters: "slider.horizontal.3"
        case .security: "lock.shield"
        case .defaultPrivileges: "person.badge.key"
        case .statistics: "chart.bar"
        case .sql: "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Display Helpers

extension SQLServerDatabaseOption.UserAccessOption {
    var displayName: String {
        switch self {
        case .multiUser: "Multi User"
        case .singleUser: "Single User"
        case .restrictedUser: "Restricted User"
        }
    }

    static func fromDescription(_ desc: String) -> Self {
        switch desc.uppercased() {
        case "SINGLE_USER": return .singleUser
        case "RESTRICTED_USER": return .restrictedUser
        default: return .multiUser
        }
    }
}
