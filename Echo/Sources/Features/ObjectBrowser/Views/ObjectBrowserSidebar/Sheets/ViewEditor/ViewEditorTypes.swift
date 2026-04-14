import Foundation

// MARK: - Window Value

struct ViewEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let schemaName: String
    let viewName: String?
    let isMaterialized: Bool

    var isEditing: Bool { viewName != nil }
}

// MARK: - Pages

enum ViewEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case definition
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .definition: "Definition"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .definition: "curlybraces"
        case .sql: "doc.text"
        }
    }
}
