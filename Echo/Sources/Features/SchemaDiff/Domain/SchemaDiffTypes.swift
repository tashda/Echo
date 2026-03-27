import Foundation

enum SchemaDiffStatus: String, CaseIterable, Sendable {
    case added = "Added"
    case removed = "Removed"
    case modified = "Modified"
    case identical = "Identical"

    var icon: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .identical: return "checkmark.circle.fill"
        }
    }
}

struct SchemaDiffItem: Identifiable, Sendable {
    let id = UUID()
    let objectType: String
    let objectName: String
    let status: SchemaDiffStatus
    let sourceDDL: String?
    let targetDDL: String?

    var qualifiedName: String {
        "\(objectType): \(objectName)"
    }
}
