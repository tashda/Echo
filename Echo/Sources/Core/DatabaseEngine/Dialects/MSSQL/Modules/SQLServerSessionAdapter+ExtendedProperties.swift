import Foundation
import SQLServerKit

extension SQLServerSessionAdapter: ExtendedPropertiesProviding {

    func listExtendedProperties(
        schema: String,
        objectType: String,
        objectName: String,
        childType: String?,
        childName: String?
    ) async throws -> [ExtendedPropertyInfo] {
        let target = ExtendedPropertyTarget(
            schema: schema,
            level1Type: objectType,
            level1Name: objectName,
            level2Type: childType,
            level2Name: childName
        )
        let props = try await client.extendedProperties.list(target: target)
        return props.map { ExtendedPropertyInfo(name: $0.name, value: $0.value) }
    }

    func listExtendedPropertiesForAllColumns(
        schema: String,
        table: String
    ) async throws -> [String: [ExtendedPropertyInfo]] {
        let columnProps = try await client.extendedProperties.listForAllColumns(schema: schema, table: table)
        return columnProps.mapValues { props in
            props.map { ExtendedPropertyInfo(name: $0.name, value: $0.value) }
        }
    }

    func addExtendedProperty(
        name: String,
        value: String,
        schema: String,
        objectType: String,
        objectName: String,
        childType: String?,
        childName: String?
    ) async throws {
        let target = ExtendedPropertyTarget(
            schema: schema,
            level1Type: objectType,
            level1Name: objectName,
            level2Type: childType,
            level2Name: childName
        )
        try await client.extendedProperties.add(name: name, value: value, target: target)
    }

    func updateExtendedProperty(
        name: String,
        value: String,
        schema: String,
        objectType: String,
        objectName: String,
        childType: String?,
        childName: String?
    ) async throws {
        let target = ExtendedPropertyTarget(
            schema: schema,
            level1Type: objectType,
            level1Name: objectName,
            level2Type: childType,
            level2Name: childName
        )
        try await client.extendedProperties.update(name: name, value: value, target: target)
    }

    func dropExtendedProperty(
        name: String,
        schema: String,
        objectType: String,
        objectName: String,
        childType: String?,
        childName: String?
    ) async throws {
        let target = ExtendedPropertyTarget(
            schema: schema,
            level1Type: objectType,
            level1Name: objectName,
            level2Type: childType,
            level2Name: childName
        )
        try await client.extendedProperties.drop(name: name, target: target)
    }
}
