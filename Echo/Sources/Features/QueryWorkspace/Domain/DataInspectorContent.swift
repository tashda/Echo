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
    /// One column of the selected cell's row, for the row-detail card (plan I4).
    struct RowField: Sendable, Equatable {
        let name: String
        let value: String
    }

    let columnName: String
    let dataType: String
    let rawValue: String
    let valueKind: ResultGridValueKind
    /// The row's number in the grid, counting from 1.
    var rowNumber: Int?
    var rowFields: [RowField] = []
}

struct SQLHelpInspectorContent: Sendable, Equatable {
    struct Section: Sendable, Equatable, Identifiable {
        let id: String
        let title: String
        let value: String

        init(id: String, title: String, value: String) {
            self.id = id
            self.title = title
            self.value = value
        }
    }

    let title: String
    let category: String
    let summary: String
    let matchedText: String
    let syntax: String?
    let example: String?
    let notes: [String]
    let relatedTopics: [String]
    let sections: [Section]
}

enum DataInspectorContent: Sendable, Equatable {
    case databaseObject(DatabaseObjectInspectorContent)
    case foreignKey(DatabaseObjectInspectorContent)
    case json(JsonInspectorContent)
    case jobHistory(JobHistoryInspectorContent)
    case cellValue(CellValueInspectorContent)
    case sqlHelp(SQLHelpInspectorContent)

    var isJson: Bool {
        if case .json = self { return true }
        return false
    }
}
