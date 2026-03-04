import SwiftUI

struct SnapshotInput: Equatable {
    let database: DatabaseInfo
    let normalizedQuery: String?
    let selectedSchemaName: String?
    let pinnedIDs: Set<String>
    let supportedTypes: [SchemaObjectInfo.ObjectType]
}

struct SnapshotData: Equatable {
    static let empty = SnapshotData(grouped: [:], pinned: [], filteredCount: 0)
    let grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]]
    let pinned: [SchemaObjectInfo]
    let filteredCount: Int
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
        
        for schema in schemas {
            for object in schema.objects {
                guard supportedSet.contains(object.type) else { continue }
                if let query = normalizedQuery, !query.isEmpty, !objectMatchesQuery(object, normalizedQuery: query) {
                    continue
                }
                grouped[object.type, default: []].append(object)
                filteredCount += 1
                if pinnedIDs.contains(object.id) {
                    pinnedList.append(object)
                }
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
        
        return SnapshotData(grouped: grouped, pinned: pinnedList, filteredCount: filteredCount)
    }
    
    private static func objectMatchesQuery(_ object: SchemaObjectInfo, normalizedQuery: String) -> Bool {
        let query = normalizedQuery
        if object.name.lowercased().contains(query) { return true }
        if object.schema.lowercased().contains(query) { return true }
        return object.fullName.lowercased().contains(query)
    }
}
