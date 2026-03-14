import Foundation

struct ForeignKeyInspectorContent: Sendable, Equatable {
    struct Field: Sendable, Equatable, Identifiable {
        let id: UUID
        let label: String
        let value: String

        init(label: String, value: String) {
            self.id = UUID()
            self.label = label
            self.value = value
        }
    }

    let title: String
    let subtitle: String?
    let fields: [Field]
    let related: [ForeignKeyInspectorContent]
    let lookupQuerySQL: String?
    let errorMessage: String?

    init(
        title: String,
        subtitle: String? = nil,
        fields: [Field],
        related: [ForeignKeyInspectorContent] = [],
        lookupQuerySQL: String? = nil,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.fields = fields
        self.related = related
        self.lookupQuerySQL = lookupQuerySQL
        self.errorMessage = errorMessage
    }
}

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
    case foreignKey(ForeignKeyInspectorContent)
    case json(JsonInspectorContent)
    case jobHistory(JobHistoryInspectorContent)
    case cellValue(CellValueInspectorContent)

    var isJson: Bool {
        if case .json = self { return true }
        return false
    }
}
