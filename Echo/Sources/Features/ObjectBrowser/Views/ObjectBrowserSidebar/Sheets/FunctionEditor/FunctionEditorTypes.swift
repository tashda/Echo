import Foundation

// MARK: - Window Value

struct FunctionEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let schemaName: String
    let functionName: String?

    var isEditing: Bool { functionName != nil }
}

// MARK: - Pages

enum FunctionEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case definition
    case parameters
    case options
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .definition: "Definition"
        case .parameters: "Parameters"
        case .options: "Options"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .definition: "curlybraces"
        case .parameters: "list.bullet.rectangle"
        case .options: "gearshape"
        case .sql: "doc.text"
        }
    }
}

// MARK: - Parameter Draft

struct FunctionParameterDraft: Identifiable {
    let id: UUID
    var name: String
    var dataType: String
    var mode: ParameterMode
    var defaultValue: String

    init(
        id: UUID = UUID(),
        name: String = "",
        dataType: String = "text",
        mode: ParameterMode = .in,
        defaultValue: String = ""
    ) {
        self.id = id
        self.name = name
        self.dataType = dataType
        self.mode = mode
        self.defaultValue = defaultValue
    }
}

// MARK: - Parameter Mode

enum ParameterMode: String, CaseIterable, Identifiable {
    case `in` = "IN"
    case out = "OUT"
    case `inout` = "INOUT"
    case variadic = "VARIADIC"

    var id: String { rawValue }
}

// MARK: - Volatility

enum FunctionVolatility: String, CaseIterable, Identifiable {
    case volatile = "VOLATILE"
    case stable = "STABLE"
    case immutable = "IMMUTABLE"

    var id: String { rawValue }
}

// MARK: - Parallel Safety

enum FunctionParallelSafety: String, CaseIterable, Identifiable {
    case unsafe = "UNSAFE"
    case restricted = "RESTRICTED"
    case safe = "SAFE"

    var id: String { rawValue }
}

// MARK: - Security Type

enum FunctionSecurityType: String, CaseIterable, Identifiable {
    case invoker = "INVOKER"
    case definer = "DEFINER"

    var id: String { rawValue }
}
