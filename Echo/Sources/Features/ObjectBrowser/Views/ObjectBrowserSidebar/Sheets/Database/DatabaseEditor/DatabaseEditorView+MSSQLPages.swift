import SwiftUI
import SQLServerKit

// MARK: - MSSQL General Page

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlGeneralPage(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Information") {
            PropertyRow(title: "Name") {
                Text(props.name)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Owner") {
                Text(props.owner)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Status") {
                Text(props.stateDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Date Created") {
                Text(props.createDate)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Size") {
                Text(String(format: "%.2f MB", props.sizeMB))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Active Sessions") {
                Text("\(props.activeSessions)")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Collation") {
                Text(props.collationName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Backup") {
            PropertyRow(title: "Last Database Backup") {
                Text(props.lastBackupDate ?? "Never")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Last Log Backup") {
                Text(props.lastLogBackupDate ?? "Never")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        if let version = session.databaseStructure?.serverVersion {
            Section("Server") {
                PropertyRow(title: "Version") {
                    Text(version)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }
}
