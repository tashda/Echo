import SwiftUI

/// Lightweight identity for change detection — O(1) equality check.
/// Used as `.task(id:)` to avoid deep-comparing the entire DatabaseInfo tree.
struct SnapshotIdentity: Equatable {
    let databaseName: String
    let schemaCount: Int
    let objectCount: Int
    let extensionCount: Int
    let pinnedIDs: Set<String>
    let supportedTypes: [SchemaObjectInfo.ObjectType]
}

struct SnapshotData: Equatable, Sendable {
    static let empty = SnapshotData(grouped: [:], pinned: [], filteredCount: 0)
    let grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]]
    let pinned: [SchemaObjectInfo]
    let filteredCount: Int
}

enum SnapshotBuilder {
    @concurrent static func buildData(
        from database: DatabaseInfo,
        pinnedIDs: Set<String>,
        supportedTypes: [SchemaObjectInfo.ObjectType]
    ) async -> SnapshotData {
        let supportedSet = Set(supportedTypes)

        var grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]] = [:]
        var pinnedList: [SchemaObjectInfo] = []
        var filteredCount = 0

        for schema in database.schemas {
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
        for ext in database.extensions {
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
