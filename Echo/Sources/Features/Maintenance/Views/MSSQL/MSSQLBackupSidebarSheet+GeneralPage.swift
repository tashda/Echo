import SwiftUI
import SQLServerKit

// MARK: - General Page

extension MSSQLBackupSidebarSheet {
    var generalPage: some View {
        Group {
            Section("Database") {
                PropertyRow(title: "Name") {
                    Text(viewModel.databaseName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    PropertyRow(title: "Type") {
                        Picker("", selection: $viewModel.backupType) {
                            ForEach(SQLServerBackupType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    Text(backupTypeDescription)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } header: {
                Text("Backup Type")
            }

            backupScopeSection

            destinationSection

            Section("Metadata") {
                PropertyRow(
                    title: "Backup Name",
                    info: "A descriptive label stored in the backup file header. Helps identify backups when listing backup sets later."
                ) {
                    TextField("", text: $viewModel.backupName, prompt: Text("Full Backup"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(
                    title: "Description",
                    info: "An optional description stored in the backup header. Visible when listing backup sets."
                ) {
                    TextField("", text: $viewModel.backupDescription, prompt: Text("Optional description"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var backupTypeDescription: String {
        switch viewModel.backupType {
        case .full: return "Complete backup of the entire database."
        case .differential: return "Only changes since the last full backup."
        case .log: return "Transaction log for point-in-time recovery."
        }
    }

}
