import Foundation
import SQLServerKit

extension MSSQLMaintenanceBackupsView {
    func pushBackupInspector(_ entry: SQLServerBackupHistoryEntry, toggle: Bool) {
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Database", value: entry.serverName),
            .init(label: "Backup Type", value: entry.typeDescription),
            .init(label: "Started", value: entry.startDate?.formatted(date: .abbreviated, time: .shortened) ?? "\u{2014}"),
            .init(label: "Finished", value: entry.finishDate?.formatted(date: .abbreviated, time: .shortened) ?? "\u{2014}"),
            .init(label: "Size", value: ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .binary)),
            .init(label: "Compressed Size", value: entry.compressedSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .binary) } ?? "N/A"),
            .init(label: "Physical Device", value: entry.physicalPath),
            .init(label: "Recovery Model", value: entry.recoveryModel),
            .init(label: "Server", value: entry.serverName)
        ]
        let title = entry.name ?? "Backup #\(entry.id)"
        let content = DatabaseObjectInspectorContent(title: title, subtitle: "Backup Entry", fields: fields)

        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: title, appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }
}
