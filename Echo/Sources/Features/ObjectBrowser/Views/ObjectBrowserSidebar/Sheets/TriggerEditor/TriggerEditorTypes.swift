import Foundation

// MARK: - Window Value

struct TriggerEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let schemaName: String
    let tableName: String
    let triggerName: String?

    var isEditing: Bool { triggerName != nil }
}

// MARK: - Pages

enum TriggerEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case events
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .events: "Events"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .events: "bolt"
        case .sql: "doc.text"
        }
    }
}

// MARK: - Trigger Timing

enum TriggerTiming: String, CaseIterable, Identifiable {
    case before = "BEFORE"
    case after = "AFTER"
    case insteadOf = "INSTEAD OF"

    var id: String { rawValue }
}

// MARK: - Trigger For Each

enum TriggerForEach: String, CaseIterable, Identifiable {
    case row = "ROW"
    case statement = "STATEMENT"

    var id: String { rawValue }
}
