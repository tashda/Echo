import Foundation

// MARK: - Window Value

struct PublicationEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let publicationName: String?

    var isEditing: Bool { publicationName != nil }
}

// MARK: - Pages

enum PublicationEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case tables
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .tables: "Tables"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "doc.text"
        case .tables: "tablecells"
        case .sql: "scroll"
        }
    }
}
