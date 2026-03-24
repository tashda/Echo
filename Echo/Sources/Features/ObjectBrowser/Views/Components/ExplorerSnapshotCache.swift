import SwiftUI

struct SnapshotInput: Equatable {
    let database: DatabaseInfo
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

        let schemas = input.database.schemas

        var grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]] = [:]
        var pinnedList: [SchemaObjectInfo] = []
        var filteredCount = 0

        for schema in schemas {
            for object in schema.objects {
                guard supportedSet.contains(object.type) else { continue }
                grouped[object.type, default: []].append(object)
                filteredCount += 1
                if pinnedIDs.contains(object.id) {
                    pinnedList.append(object)
                }
            }
        }

        // Process extensions (database-level)
        for ext in input.database.extensions {
            guard supportedSet.contains(.extension) else { continue }

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

        return SnapshotData(grouped: grouped, pinned: pinnedList, filteredCount: filteredCount)
    }
}
