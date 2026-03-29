import Foundation

// MARK: - Window Value

struct TypeEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let schemaName: String
    let typeName: String?
    let typeCategory: TypeCategory

    var isEditing: Bool { typeName != nil }
}

// MARK: - Type Category

enum TypeCategory: String, Codable, CaseIterable, Identifiable {
    case composite
    case `enum`
    case range
    case domain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .composite: "Composite"
        case .enum: "Enum"
        case .range: "Range"
        case .domain: "Domain"
        }
    }
}

// MARK: - Pages

enum TypeEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case attributes
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .attributes: "Attributes"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .attributes: "list.bullet.rectangle"
        case .sql: "doc.text"
        }
    }
}

// MARK: - Attribute Draft

struct TypeAttributeDraft: Identifiable {
    let id: UUID
    var name: String
    var dataType: String

    init(id: UUID = UUID(), name: String = "", dataType: String = "") {
        self.id = id
        self.name = name
        self.dataType = dataType
    }
}

// MARK: - Enum Value Draft

struct EnumValueDraft: Identifiable {
    let id: UUID
    var value: String

    init(id: UUID = UUID(), value: String = "") {
        self.id = id
        self.value = value
    }
}

// MARK: - Domain Constraint Draft

struct DomainConstraintDraft: Identifiable {
    let id: UUID
    var name: String
    var expression: String

    init(id: UUID = UUID(), name: String = "", expression: String = "") {
        self.id = id
        self.name = name
        self.expression = expression
    }
}
