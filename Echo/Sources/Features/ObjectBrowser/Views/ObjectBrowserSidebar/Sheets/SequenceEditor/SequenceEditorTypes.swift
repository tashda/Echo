import Foundation

// MARK: - Window Value

struct SequenceEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let schemaName: String
    let sequenceName: String?

    var isEditing: Bool { sequenceName != nil }
}

// MARK: - Pages

enum SequenceEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case values
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .values: "Values"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .values: "number"
        case .sql: "doc.text"
        }
    }
}
