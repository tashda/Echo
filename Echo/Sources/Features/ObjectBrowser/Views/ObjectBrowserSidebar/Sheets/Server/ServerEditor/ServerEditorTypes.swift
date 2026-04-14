import Foundation
import SQLServerKit

// MARK: - Window Value

struct ServerEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
}

// MARK: - Pages

enum ServerEditorPage: String, Hashable, CaseIterable, Identifiable {
    case general
    case memory
    case processors
    case security
    case connections
    case databaseSettings
    case advanced
    case startupParameters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .memory: "Memory"
        case .processors: "Processors"
        case .security: "Security"
        case .connections: "Connections"
        case .databaseSettings: "Database Settings"
        case .advanced: "Advanced"
        case .startupParameters: "Startup Parameters"
        }
    }

    var icon: String {
        switch self {
        case .general: "server.rack"
        case .memory: "memorychip"
        case .processors: "cpu"
        case .security: "lock.shield"
        case .connections: "network"
        case .databaseSettings: "externaldrive"
        case .advanced: "gearshape.2"
        case .startupParameters: "flag"
        }
    }
}
