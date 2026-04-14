import Foundation
import Observation

@Observable
final class TypeEditorViewModel {
    let connectionSessionID: UUID
    let schemaName: String
    let existingTypeName: String?
    let typeCategory: TypeCategory

    var isEditing: Bool { existingTypeName != nil }

    // MARK: - Form State (Shared)

    var typeName = ""
    var owner = ""
    var description = ""

    // MARK: - Composite State

    var attributes: [TypeAttributeDraft] = [TypeAttributeDraft()]

    // MARK: - Enum State

    var enumValues: [EnumValueDraft] = [EnumValueDraft()]

    // MARK: - Range State

    var subtype = ""
    var subtypeOpClass = ""
    var collation = ""
    var canonicalFunction = ""
    var subtypeDiffFunction = ""

    // MARK: - Domain State

    var baseDataType = ""
    var defaultValue = ""
    var isNotNull = false
    var domainConstraints: [DomainConstraintDraft] = []

    // MARK: - Loading State

    var isLoading = false
    var isSubmitting = false
    var didComplete = false
    var errorMessage: String?

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored private var snapshot: Snapshot?

    struct Snapshot {
        let typeName: String
        let owner: String
        let description: String
        let attributeHash: Int
        let enumValueHash: Int
        let subtype: String
        let subtypeOpClass: String
        let collation: String
        let baseDataType: String
        let defaultValue: String
        let isNotNull: Bool
        let constraintHash: Int
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            typeName: typeName,
            owner: owner,
            description: description,
            attributeHash: attributeHash,
            enumValueHash: enumValueHash,
            subtype: subtype,
            subtypeOpClass: subtypeOpClass,
            collation: collation,
            baseDataType: baseDataType,
            defaultValue: defaultValue,
            isNotNull: isNotNull,
            constraintHash: constraintHash
        )
    }

    private var attributeHash: Int {
        var hasher = Hasher()
        for attr in attributes {
            hasher.combine(attr.name)
            hasher.combine(attr.dataType)
        }
        hasher.combine(attributes.count)
        return hasher.finalize()
    }

    private var enumValueHash: Int {
        var hasher = Hasher()
        for val in enumValues { hasher.combine(val.value) }
        hasher.combine(enumValues.count)
        return hasher.finalize()
    }

    private var constraintHash: Int {
        var hasher = Hasher()
        for c in domainConstraints {
            hasher.combine(c.name)
            hasher.combine(c.expression)
        }
        hasher.combine(domainConstraints.count)
        return hasher.finalize()
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }
        if typeName != snapshot.typeName { return true }
        if owner != snapshot.owner { return true }
        if description != snapshot.description { return true }
        switch typeCategory {
        case .composite:
            if attributeHash != snapshot.attributeHash { return true }
        case .enum:
            if enumValueHash != snapshot.enumValueHash { return true }
        case .range:
            if subtype != snapshot.subtype { return true }
            if subtypeOpClass != snapshot.subtypeOpClass { return true }
            if collation != snapshot.collation { return true }
        case .domain:
            if baseDataType != snapshot.baseDataType { return true }
            if defaultValue != snapshot.defaultValue { return true }
            if isNotNull != snapshot.isNotNull { return true }
            if constraintHash != snapshot.constraintHash { return true }
        }
        return false
    }

    // MARK: - Dialect

    let dialect: any TypeEditorDialect

    // MARK: - Init

    init(connectionSessionID: UUID, schemaName: String, existingTypeName: String?, typeCategory: TypeCategory, dialect: any TypeEditorDialect) {
        self.connectionSessionID = connectionSessionID
        self.schemaName = schemaName
        self.existingTypeName = existingTypeName
        self.typeCategory = typeCategory
        self.dialect = dialect
        if let existingTypeName {
            self.typeName = existingTypeName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = typeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }

        switch typeCategory {
        case .composite:
            return attributes.contains {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .enum:
            return enumValues.contains {
                !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .range:
            return !subtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .domain:
            return !baseDataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Pages

    var pages: [TypeEditorPage] {
        TypeEditorPage.allCases
    }

    /// Label for the attributes page based on the type category.
    var attributesPageTitle: String {
        switch typeCategory {
        case .composite: "Attributes"
        case .enum: "Values"
        case .range: "Range Options"
        case .domain: "Domain Options"
        }
    }
}
