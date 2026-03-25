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

    // MARK: - Backup Scope

    @ViewBuilder
    private var backupScopeSection: some View {
        if viewModel.backupType != .log {
            Section("Backup Scope") {
                PropertyRow(
                    title: "Scope",
                    info: "Choose whether to back up the entire database, specific files, or specific filegroups."
                ) {
                    Picker("", selection: $viewModel.backupScope) {
                        ForEach(BackupScopeType.allCases, id: \.self) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.backupScope) { _, newValue in
                        if newValue != .database && viewModel.databaseFiles.isEmpty {
                            Task { await viewModel.loadDatabaseFiles() }
                        }
                    }
                }

                if viewModel.backupScope != .database {
                    if viewModel.isLoadingFiles {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading files\u{2026}")
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Text.secondary)
                            Spacer()
                        }
                    } else {
                        backupScopeFileList
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var backupScopeFileList: some View {
        let filteredFiles: [Binding<SelectableDatabaseFile>] = {
            switch viewModel.backupScope {
            case .database:
                return []
            case .files:
                return $viewModel.databaseFiles.filter { $0.wrappedValue.fileInfo.type == "D" }
            case .filegroups:
                return $viewModel.databaseFiles.filter { $0.wrappedValue.fileInfo.filegroupName != nil }
            }
        }()

        if filteredFiles.isEmpty {
            Text("No matching files found.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        } else {
            ForEach(filteredFiles) { $file in
                let label: String = {
                    switch viewModel.backupScope {
                    case .filegroups:
                        return file.fileInfo.filegroupName ?? file.fileInfo.logicalName
                    default:
                        return file.fileInfo.logicalName
                    }
                }()

                Toggle(isOn: $file.isSelected) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(TypographyTokens.formLabel)
                        Text(file.fileInfo.physicalName)
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    // MARK: - Destination

    private var destinationSection: some View {
        Section("Destination") {
            PropertyRow(
                title: "Destination Type",
                info: "Choose Disk for a local server path, or URL for Azure Blob Storage."
            ) {
                Picker("", selection: $viewModel.destinationType) {
                    ForEach(BackupDestinationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if viewModel.destinationType == .url {
                PropertyRow(
                    title: "Credential",
                    info: "The SQL Server credential name that provides access to the Azure Blob Storage container. Must already exist on the server."
                ) {
                    TextField("", text: $viewModel.credentialName, prompt: Text("e.g. MyAzureCredential"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            ForEach($viewModel.destinations) { $entry in
                HStack(spacing: SpacingTokens.xs) {
                    TextField(
                        "",
                        text: $entry.path,
                        prompt: Text(destinationPrompt)
                    )
                    .textFieldStyle(.plain)
                    .font(TypographyTokens.monospaced)

                    if viewModel.destinations.count > 1 {
                        Button {
                            viewModel.removeDestination(id: entry.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(ColorTokens.Status.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                viewModel.addDestination()
            } label: {
                Label("Add Device", systemImage: "plus.circle")
                    .font(TypographyTokens.formLabel)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ColorTokens.accent)
        }
    }

    private var destinationPrompt: String {
        switch viewModel.destinationType {
        case .disk: return "/var/backups/mydb.bak"
        case .url: return "https://account.blob.core.windows.net/container/mydb.bak"
        }
    }
}
