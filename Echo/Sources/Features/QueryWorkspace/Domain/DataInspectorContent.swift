import Foundation

struct JsonInspectorContent: Sendable, Equatable {
    let title: String
    let subtitle: String?
    let rawJSON: String
}

struct JobHistoryInspectorContent: Sendable, Equatable {
    let jobName: String
    let stepId: Int
    let stepName: String
    let status: String
    let runDate: String
    let duration: String
    let message: String
}

struct CellValueInspectorContent: Sendable, Equatable {
    let columnName: String
    let dataType: String
    let rawValue: String
    let valueKind: ResultGridValueKind
}

enum DataInspectorContent: Sendable, Equatable {
    case databaseObject(DatabaseObjectInspectorContent)
    case foreignKey(DatabaseObjectInspectorContent)
    case json(JsonInspectorContent)
    case jobHistory(JobHistoryInspectorContent)
    case cellValue(CellValueInspectorContent)

    var isJson: Bool {
        if case .json = self { return true }
        return false
    }
}
