import Foundation

extension TableStructureEditorViewModel {
    struct ColumnModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let dataType: String
            let isNullable: Bool
            let defaultValue: String?
            let generatedExpression: String?
            let isIdentity: Bool
            let identitySeed: Int?
            let identityIncrement: Int?
            let identityGeneration: String?
            let collation: String?

            init(name: String, dataType: String, isNullable: Bool, defaultValue: String? = nil, generatedExpression: String? = nil, isIdentity: Bool = false, identitySeed: Int? = nil, identityIncrement: Int? = nil, identityGeneration: String? = nil, collation: String? = nil) {
                self.name = name; self.dataType = dataType; self.isNullable = isNullable; self.defaultValue = defaultValue; self.generatedExpression = generatedExpression
                self.isIdentity = isIdentity; self.identitySeed = identitySeed; self.identityIncrement = identityIncrement; self.identityGeneration = identityGeneration; self.collation = collation
            }
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var dataType: String
        var isNullable: Bool
        var defaultValue: String?
        var generatedExpression: String?
        var isIdentity: Bool
        var identitySeed: Int?
        var identityIncrement: Int?
        var identityGeneration: String?
        var collation: String?
        var isDeleted: Bool = false

        init(original: Snapshot?, name: String, dataType: String, isNullable: Bool, defaultValue: String? = nil, generatedExpression: String? = nil, isIdentity: Bool = false, identitySeed: Int? = nil, identityIncrement: Int? = nil, identityGeneration: String? = nil, collation: String? = nil) {
            self.original = original; self.name = name; self.dataType = dataType; self.isNullable = isNullable; self.defaultValue = defaultValue; self.generatedExpression = generatedExpression
            self.isIdentity = isIdentity; self.identitySeed = identitySeed; self.identityIncrement = identityIncrement; self.identityGeneration = identityGeneration; self.collation = collation
        }

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

        var hasIdentityChange: Bool {
            guard let original else { return isIdentity }
            return original.isIdentity != isIdentity || original.identitySeed != identitySeed || original.identityIncrement != identityIncrement || original.identityGeneration != identityGeneration
        }

        var hasCollationChange: Bool {
            guard let original else { return collation != nil }
            return original.collation != collation
        }

        var isDirty: Bool {
            if isDeleted { return true }
            if isNew { return true }
            return hasRename || hasTypeChange || hasNullabilityChange || hasDefaultChange || hasExpressionChange || hasIdentityChange || hasCollationChange
        }
    }

    struct IndexModel: Identifiable, Hashable {
        struct Column: Identifiable, Hashable {
            struct Snapshot: Hashable {
                let name: String
                let sortOrder: SortOrder
                let isIncluded: Bool

                init(name: String, sortOrder: SortOrder, isIncluded: Bool = false) {
                    self.name = name; self.sortOrder = sortOrder; self.isIncluded = isIncluded
                }
            }

            enum SortOrder: String, CaseIterable, Hashable {
                case ascending, descending
                var displayName: String { self == .ascending ? "Ascending" : "Descending" }
                var sqlKeyword: String { self == .ascending ? "ASC" : "DESC" }
            }

            let id = UUID()
            var name: String
            var sortOrder: SortOrder
            var isIncluded: Bool
            var snapshot: Snapshot { Snapshot(name: name, sortOrder: sortOrder, isIncluded: isIncluded) }

            init(name: String, sortOrder: SortOrder, isIncluded: Bool = false) {
                self.name = name; self.sortOrder = sortOrder; self.isIncluded = isIncluded
            }
        }

        struct Snapshot: Hashable {
            let name: String
            let columns: [Column.Snapshot]
            let isUnique: Bool
            let filterCondition: String?
            let indexType: String?

            init(name: String, columns: [Column.Snapshot], isUnique: Bool, filterCondition: String?, indexType: String? = nil) {
                self.name = name; self.columns = columns; self.isUnique = isUnique; self.filterCondition = filterCondition; self.indexType = indexType
            }
        }

        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [Column]
        var isUnique: Bool
        var filterCondition: String
        var indexType: String
        var isDeleted: Bool = false

        init(original: Snapshot?, name: String, columns: [Column], isUnique: Bool, filterCondition: String, indexType: String = "btree") {
            self.original = original; self.name = name; self.columns = columns; self.isUnique = isUnique; self.filterCondition = filterCondition; self.indexType = indexType
        }

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
            let originalType = (original.indexType ?? "btree").lowercased()
            if originalType != indexType.lowercased() { return true }
            let originalFilter = original.filterCondition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if originalFilter != (effectiveFilterCondition ?? "") { return true }
            if original.columns.count != columns.count { return true }
            for (lhs, rhs) in zip(original.columns, columns.map { $0.snapshot }) {
                if lhs.name != rhs.name || lhs.sortOrder != rhs.sortOrder || lhs.isIncluded != rhs.isIncluded { return true }
            }
            return false
        }
    }

    struct UniqueConstraintModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let columns: [String]
            let isDeferrable: Bool
            let isInitiallyDeferred: Bool

            init(name: String, columns: [String], isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
                self.name = name; self.columns = columns; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
            }
        }
        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]
        var isDeferrable: Bool
        var isInitiallyDeferred: Bool
        var isDeleted: Bool = false

        init(original: Snapshot?, name: String, columns: [String], isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
            self.original = original; self.name = name; self.columns = columns; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
        }
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            return original.name != name || original.columns != columns || original.isDeferrable != isDeferrable || original.isInitiallyDeferred != isInitiallyDeferred
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
            let isDeferrable: Bool
            let isInitiallyDeferred: Bool

            init(name: String, columns: [String], referencedSchema: String, referencedTable: String, referencedColumns: [String], onUpdate: String?, onDelete: String?, isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
                self.name = name; self.columns = columns; self.referencedSchema = referencedSchema; self.referencedTable = referencedTable; self.referencedColumns = referencedColumns
                self.onUpdate = onUpdate; self.onDelete = onDelete; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
            }
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
        var isDeferrable: Bool
        var isInitiallyDeferred: Bool
        var isDeleted: Bool = false

        init(original: Snapshot?, name: String, columns: [String], referencedSchema: String, referencedTable: String, referencedColumns: [String], onUpdate: String? = nil, onDelete: String? = nil, isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
            self.original = original; self.name = name; self.columns = columns; self.referencedSchema = referencedSchema; self.referencedTable = referencedTable; self.referencedColumns = referencedColumns
            self.onUpdate = onUpdate; self.onDelete = onDelete; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
        }
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            return original.name != name || original.columns != columns ||
                original.referencedSchema != referencedSchema || original.referencedTable != referencedTable ||
                original.referencedColumns != referencedColumns || original.onUpdate != onUpdate || original.onDelete != onDelete ||
                original.isDeferrable != isDeferrable || original.isInitiallyDeferred != isInitiallyDeferred
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
            let isDeferrable: Bool
            let isInitiallyDeferred: Bool

            init(name: String, columns: [String], isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
                self.name = name; self.columns = columns; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
            }
        }
        let id = UUID()
        let original: Snapshot?
        var name: String
        var columns: [String]
        var isDeferrable: Bool
        var isInitiallyDeferred: Bool

        init(original: Snapshot?, name: String, columns: [String], isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
            self.original = original; self.name = name; self.columns = columns; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
        }
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            guard let original else { return true }
            return original.name != name || original.columns != columns || original.isDeferrable != isDeferrable || original.isInitiallyDeferred != isInitiallyDeferred
        }
    }

    struct CheckConstraintModel: Identifiable, Hashable {
        struct Snapshot: Hashable {
            let name: String
            let expression: String
        }
        let id = UUID()
        let original: Snapshot?
        var name: String
        var expression: String
        var isDeleted: Bool = false
        var isNew: Bool { original == nil }
        var isDirty: Bool {
            if isDeleted { return true }
            guard let original else { return true }
            return original.name != name || original.expression != expression
        }
    }
}
