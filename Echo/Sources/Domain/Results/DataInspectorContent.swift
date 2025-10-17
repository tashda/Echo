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

    init(title: String, subtitle: String? = nil, fields: [Field], related: [ForeignKeyInspectorContent] = []) {
        self.title = title
        self.subtitle = subtitle
        self.fields = fields
        self.related = related
    }
}

struct JsonInspectorContent: Sendable, Equatable {
    let title: String
    let subtitle: String?
    let outline: JsonOutlineNode
}

enum DataInspectorContent: Sendable, Equatable {
    case foreignKey(ForeignKeyInspectorContent)
    case json(JsonInspectorContent)
}
