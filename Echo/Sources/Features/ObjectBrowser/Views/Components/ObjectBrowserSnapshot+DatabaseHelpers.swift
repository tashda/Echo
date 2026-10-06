import Foundation

extension ObjectBrowserSnapshotBuilder {
    static func visibleDatabases(
        for session: ConnectionSession,
        databases: [DatabaseSummary],
        settings: GlobalSettings,
        hideOffline: Bool
    ) -> [DatabaseSummary] {
        let hideInaccessible = settings.hideInaccessibleDatabases
        return databases
            .filter { !hideInaccessible || $0.isAccessible }
            .filter { !hideOffline || $0.isOnline }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func groupedObjects(
        for database: DatabaseInfo,
        supportedTypes: [SchemaObjectInfo.ObjectType]
    ) -> [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]] {
        var grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]] = [:]
        let supportedSet = Set(supportedTypes)

        for schema in database.schemas {
            for object in schema.objects where supportedSet.contains(object.type) {
                grouped[object.type, default: []].append(object)
            }
        }

        for ext in database.extensions where supportedSet.contains(.extension) {
            grouped[.extension, default: []].append(ext)
        }

        for key in grouped.keys {
            grouped[key]?.sort {
                $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
            }
        }

        return grouped
    }
}
