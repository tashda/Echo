import Foundation

extension TableStructureEditorViewModel {
    struct ColumnModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let dataType: String
            let isNullable: Bool
            let defaultValue: String?
            let generatedExpression: String?
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var dataType: String
        var isNullable: Bool
        var defaultValue: String?
        var generatedExpression: String?
        var isDeleted: Bool = false

        var isNew: Bool { original == nil }
        var referenceName: String { original?.name ?? name }

        var hasRename: Bool {
            guard let original else { return false }
            return original.name != name
        }

        var hasTypeChange: Bool {
            guard let original else { return false }
            return original.dataType != dataType
        }

        var hasNullabilityChange: Bool {
            guard let original else { return false }
            return original.isNullable != isNullable
        }

        var hasDefaultChange: Bool {
            guard let original else { return defaultValue != nil }
            return original.defaultValue != defaultValue
        }

        var hasExpressionChange: Bool {
            guard let original else { return generatedExpression != nil }
            return original.generatedExpression != generatedExpression
        }

        var isDirty: Bool {
            if isDeleted { return true }
            if isNew { return true }
            return hasRename || hasTypeChange || hasNullabilityChange || hasDefaultChange || hasExpressionChange
        }
    }

    struct IndexModel: Identifiable, Hashable {
        struct Column: Identifiable, Hashable {
            struct Snapshot: Hashable {
                let name: String
                let sortOrder: SortOrder
            }

            enum SortOrder: String, CaseIterable, Hashable {
                case ascending, descending
                var displayName: String { self == .ascending ? "Ascending" : "Descending" }
                var sqlKeyword: String { self == .ascending ? "ASC" : "DESC" }
            }

            let id = UUID()
            var name: String
            var sortOrder: SortOrder
            var snapshot: Snapshot { Snapshot(name: name, sortOrder: sortOrder) }
        }

        struct Snapshot: Hashable {
            let name: String
            let columns: [Column.Snapshot]
            let isUnique: Bool
            let filterCondition: String?
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [Column]
        var isUnique: Bool
        var filterCondition: String
        var isDeleted: Bool = false

        var isNew: Bool { original == nil }
        var trimmedFilterCondition: String { filterCondition.trimmingCharacters(in: .whitespacesAndNewlines) }
        var effectiveFilterCondition: String? {
            let trimmed = trimmedFilterCondition
            return trimmed.isEmpty ? nil : trimmed
        }

        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            if original.name != name || original.isUnique != isUnique { return true }
            let originalFilter = original.filterCondition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if originalFilter != (effectiveFilterCondition ?? "") { return true }
            if original.columns.count != columns.count { return true }
            for (lhs, rhs) in zip(original.columns, columns.map { $0.snapshot }) {
                if lhs.name != rhs.name || lhs.sortOrder != rhs.sortOrder { return true }
            }
            return false
        }
    }

    struct UniqueConstraintModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let columns: [String]
        }
        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]
        var isDeleted: Bool = false
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            return original.name != name || original.columns != columns
        }
    }

    struct ForeignKeyModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let columns: [String]
            let referencedSchema: String
            let referencedTable: String
            let referencedColumns: [String]
            let onUpdate: String?
            let onDelete: String?
        }
        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]
        var referencedSchema: String
        var referencedTable: String
        var referencedColumns: [String]
        var onUpdate: String?
        var onDelete: String?
        var isDeleted: Bool = false
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            return original.name != name || original.columns != columns ||
                original.referencedSchema != referencedSchema || original.referencedTable != referencedTable ||
                original.referencedColumns != referencedColumns || original.onUpdate != onUpdate || original.onDelete != onDelete
        }
    }

    struct DependencyModel: Identifiable, Hashable {
        let name: String
        let baseColumns: [String]
        let referencedTable: String
        let referencedColumns: [String]
        let onUpdate: String?
        let onDelete: String?
        var id: String { name }
    }

    struct PrimaryKeyModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let columns: [String]
        }
        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            guard let original else { return true }
            return original.name != name || original.columns != columns
        }
    }
}
