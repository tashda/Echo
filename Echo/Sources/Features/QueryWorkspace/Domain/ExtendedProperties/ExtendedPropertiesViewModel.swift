import Foundation

@Observable
final class ExtendedPropertiesViewModel {
    var tableProperties: [ExtendedPropertyInfo] = []
    var columnProperties: [String: [ExtendedPropertyInfo]] = [:]
    var isLoading = false
    var errorMessage: String?

    var editingProperty: EditableProperty?
    var isAddingNew = false

    let schema: String
    let tableName: String
    private let session: DatabaseSession

    struct EditableProperty: Identifiable {
        let id = UUID()
        var name: String
        var value: String
        var childType: String?
        var childName: String?
        var isNew: Bool
    }

    init(session: DatabaseSession, schema: String, tableName: String) {
        self.session = session
        self.schema = schema
        self.tableName = tableName
    }

    func load() async {
        guard let provider = session as? ExtendedPropertiesProviding else {
            errorMessage = "Extended properties are not supported for this connection"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let tp = try await provider.listExtendedProperties(
                schema: schema, objectType: "TABLE", objectName: tableName,
                childType: nil, childName: nil
            )
            let cp = try await provider.listExtendedPropertiesForAllColumns(
                schema: schema, table: tableName
            )
            tableProperties = tp
            columnProperties = cp
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginAdd(childType: String? = nil, childName: String? = nil) {
        editingProperty = EditableProperty(
            name: "", value: "", childType: childType, childName: childName, isNew: true
        )
        isAddingNew = true
    }

    func beginEdit(_ property: ExtendedPropertyInfo, childType: String? = nil, childName: String? = nil) {
        editingProperty = EditableProperty(
            name: property.name, value: property.value,
            childType: childType, childName: childName, isNew: false
        )
        isAddingNew = false
    }

    func save() async {
        guard let editing = editingProperty,
              let provider = session as? ExtendedPropertiesProviding else { return }

        let trimmedName = editing.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Property name cannot be empty"
            return
        }

        do {
            if editing.isNew {
                try await provider.addExtendedProperty(
                    name: trimmedName, value: editing.value,
                    schema: schema, objectType: "TABLE", objectName: tableName,
                    childType: editing.childType, childName: editing.childName
                )
            } else {
                try await provider.updateExtendedProperty(
                    name: trimmedName, value: editing.value,
                    schema: schema, objectType: "TABLE", objectName: tableName,
                    childType: editing.childType, childName: editing.childName
                )
            }
            editingProperty = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ property: ExtendedPropertyInfo, childType: String? = nil, childName: String? = nil) async {
        guard let provider = session as? ExtendedPropertiesProviding else { return }

        do {
            try await provider.dropExtendedProperty(
                name: property.name,
                schema: schema, objectType: "TABLE", objectName: tableName,
                childType: childType, childName: childName
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelEdit() {
        editingProperty = nil
    }
}
