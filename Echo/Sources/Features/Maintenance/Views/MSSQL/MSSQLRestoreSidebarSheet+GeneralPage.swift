import SwiftUI
import SQLServerKit

// MARK: - General Page

extension MSSQLRestoreSidebarSheet {
    var generalPage: some View {
        Group {
            Section("Source") {
                PropertyRow(
                    title: "Path on server",
                    info: "The file path to the .bak backup file on the SQL Server machine. The SQL Server service account must have read access."
                ) {
                    TextField("", text: $viewModel.restoreDiskPath, prompt: Text("/var/backups/file.bak"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Spacer()
                    Button("List Backup Sets") {
                        Task { await viewModel.listBackupSets() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!viewModel.canListSets)
                }

                if viewModel.isLoadingSets {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Reading backup file\u{2026}")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                if let error = viewModel.loadError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }

            if !viewModel.backupSets.isEmpty {
                Section("Backup Sets") {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("#")
                                .frame(width: 30, alignment: .leading)
                            Text("Type")
                                .frame(width: 80, alignment: .leading)
                            Text("Database")
                                .frame(width: 100, alignment: .leading)
                            Text("Size")
                            Spacer()
                        }
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xs)

                        Divider()

                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.backupSets) { set in
                                    HStack(spacing: 0) {
                                        Text("\(set.id + 1)")
                                            .frame(width: 30, alignment: .leading)
                                        Text(set.backupTypeDescription)
                                            .frame(width: 80, alignment: .leading)
                                        Text(set.databaseName)
                                            .frame(width: 100, alignment: .leading)
                                        Text(set.formattedSize)
                                        Spacer()
                                    }
                                    .font(TypographyTokens.detail)
                                    .padding(.horizontal, SpacingTokens.sm)
                                    .padding(.vertical, 4)

                                    if set.id != viewModel.backupSets.last?.id {
                                        Divider().padding(.leading, SpacingTokens.sm)
                                    }
                                }
                            }
                        }
                        .frame(height: min(CGFloat(viewModel.backupSets.count) * 28 + 8, 140))
                    }
                    .background(ColorTokens.Background.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Target") {
                PropertyRow(
                    title: "Database Name",
                    info: "The name of the database to restore into. If it does not exist, SQL Server will create it."
                ) {
                    TextField("", text: $viewModel.restoreDatabaseName, prompt: Text("database_name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(
                    title: "File Number",
                    info: "Which backup set to restore from the file. A single .bak file can contain multiple backup sets."
                ) {
                    TextField("", value: $viewModel.fileNumber, format: .number, prompt: Text("1"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}
