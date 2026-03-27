import Foundation

// MARK: - Window Value

struct TablePropertiesWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let schemaName: String
    let tableName: String
}

// MARK: - Pages

enum TablePropertiesPage: String, Hashable, Identifiable {
    case general
    case storage
    case changeTracking
    case temporal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .storage: "Storage"
        case .changeTracking: "Change Tracking"
        case .temporal: "Temporal"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .storage: "internaldrive"
        case .changeTracking: "arrow.triangle.2.circlepath"
        case .temporal: "clock.arrow.2.circlepath"
        }
    }

    static func pages(
        for databaseType: DatabaseType,
        isSystemVersioned: Bool = false,
        changeTrackingEnabled: Bool = false
    ) -> [TablePropertiesPage] {
        switch databaseType {
        case .postgresql:
            return [.general, .storage]
        case .microsoftSQL:
            var pages: [TablePropertiesPage] = [.general, .storage]
            if changeTrackingEnabled { pages.append(.changeTracking) }
            if isSystemVersioned { pages.append(.temporal) }
            return pages
        default:
            return [.general]
        }
    }
}
