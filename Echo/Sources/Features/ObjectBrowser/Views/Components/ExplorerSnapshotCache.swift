import SwiftUI

struct SnapshotInput: Equatable {
    let database: DatabaseInfo
    let normalizedQuery: String?
    let selectedSchemaName: String?
    let pinnedIDs: Set<String>
    let supportedTypes: [SchemaObjectInfo.ObjectType]
}

struct SnapshotData: Equatable {
    static let empty = SnapshotData(grouped: [:], pinned: [], filteredCount: 0, matchingChildObjectIDs: [])
    let grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]]
    let pinned: [SchemaObjectInfo]
    let filteredCount: Int
    /// Object IDs where the object itself didn't match but a child column/parameter did.
    let matchingChildObjectIDs: Set<String>
}

struct ExplorerSnapshotCache {
    private(set) var data: SnapshotData = .empty
    private var lastInput: SnapshotInput?
    
    mutating func update(with input: SnapshotInput) {
        if let last = lastInput, last == input {
            return
        }
        lastInput = input
        let newData = ExplorerSnapshotCache.buildData(from: input)
        if newData != data {
            data = newData
        }
    }
    
    private static func buildData(from input: SnapshotInput) -> SnapshotData {
        let supportedSet = Set(input.supportedTypes)
        let pinnedIDs = input.pinnedIDs
        let normalizedQuery = input.normalizedQuery

        let schemas: [SchemaInfo]
        if let selected = input.selectedSchemaName, !selected.isEmpty {
            schemas = input.database.schemas.filter { $0.name == selected }
        } else {
            schemas = input.database.schemas
        }

        var grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]] = [:]
        var pinnedList: [SchemaObjectInfo] = []
        var filteredCount = 0
        var matchingChildIDs: Set<String> = []

        for schema in schemas {
            for object in schema.objects {
                guard supportedSet.contains(object.type) else { continue }
                if let query = normalizedQuery, !query.isEmpty {
                    let directMatch = objectMatchesQuery(object, normalizedQuery: query)
                    let childMatch = !directMatch && objectChildMatchesQuery(object, normalizedQuery: query)
                    guard directMatch || childMatch else { continue }
                    if childMatch {
                        matchingChildIDs.insert(object.id)
                    }
                }
                grouped[object.type, default: []].append(object)
                filteredCount += 1
                if pinnedIDs.contains(object.id) {
                    pinnedList.append(object)
                }
            }
        }

        // Process extensions (database-level but filtered by schema selection if applicable)
        for ext in input.database.extensions {
            guard supportedSet.contains(.extension) else { continue }
            
            // If a schema is selected, only show extensions in that schema
            if let selected = input.selectedSchemaName, !selected.isEmpty {
                guard ext.schema == selected else { continue }
            }

            if let query = normalizedQuery, !query.isEmpty {
                guard objectMatchesQuery(ext, normalizedQuery: query) else { continue }
            }

            grouped[.extension, default: []].append(ext)
            filteredCount += 1
            if pinnedIDs.contains(ext.id) {
                pinnedList.append(ext)
            }
        }

        for type in grouped.keys {
            grouped[type]?.sort { lhs, rhs in
                lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
            }
        }

        pinnedList.sort { lhs, rhs in
            lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }

        return SnapshotData(grouped: grouped, pinned: pinnedList, filteredCount: filteredCount, matchingChildObjectIDs: matchingChildIDs)
    }

    private static func objectMatchesQuery(_ object: SchemaObjectInfo, normalizedQuery: String) -> Bool {
        let query = normalizedQuery
        if object.name.lowercased().contains(query) { return true }
        if object.schema.lowercased().contains(query) { return true }
        return object.fullName.lowercased().contains(query)
    }

    private static func objectChildMatchesQuery(_ object: SchemaObjectInfo, normalizedQuery: String) -> Bool {
        for column in object.columns {
            if column.name.lowercased().contains(normalizedQuery) { return true }
        }
        for param in object.parameters {
            if param.name.lowercased().contains(normalizedQuery) { return true }
        }
        return false
    }
}
