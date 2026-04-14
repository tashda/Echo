import SwiftUI

// MARK: - General Page

extension PgBackupSidebarSheet {
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
                    PropertyRow(title: "Format") {
                        Picker("", selection: $viewModel.outputFormat) {
                            ForEach(PgDumpFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.outputFormat) { _, _ in
                            viewModel.outputURL = nil
                            viewModel.outputPath = ""
                        }
                    }

                    Text(formatDescription)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                PropertyRow(title: "Destination") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $viewModel.outputPath, prompt: Text("/path/to/backup.dump"))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                            .truncationMode(.head)
                        Button("Browse") {
                            viewModel.selectOutputFile()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if viewModel.outputFormat != .plain {
                    PropertyRow(
                        title: "Compression",
                        info: "Compression level from 0 (none) to 9 (maximum). Higher values produce smaller files but take longer."
                    ) {
                        Stepper(value: $viewModel.compression, in: 0...9) {
                            Text("\(viewModel.compression)")
                                .font(TypographyTokens.monospaced)
                                .frame(minWidth: 16, alignment: .trailing)
                        }
                    }
                }
            } header: {
                Text("Output")
            }

            Section("Connection") {
                PropertyRow(
                    title: "Encoding",
                    info: "Override the character encoding for the dump. Leave empty to use the database encoding. Common values: UTF8, LATIN1, SQL_ASCII."
                ) {
                    TextField("", text: $viewModel.encoding, prompt: Text("e.g. UTF8"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(
                    title: "Role",
                    info: "Use SET ROLE to assume this role before dumping. Useful when the connecting user has multiple roles with different permissions."
                ) {
                    TextField("", text: $viewModel.roleName, prompt: Text("e.g. backup_role"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var formatDescription: String {
        switch viewModel.outputFormat {
        case .plain: return "Readable SQL script (.sql). Cannot be used with pg_restore."
        case .custom: return "Compressed archive. Supports selective restore with pg_restore."
        case .tar: return "Portable tar archive. Compatible with standard tools."
        case .directory: return "Directory of files. Enables parallel dump and restore."
        }
    }
}

// MARK: - Scope Page

extension PgBackupSidebarSheet {
    var scopePage: some View {
        Group {
            Section("Data Selection") {
                PropertyRow(
                    title: "Schema Only",
                    info: "Dump only the object definitions (tables, views, functions) without any row data."
                ) {
                    Toggle("", isOn: $viewModel.schemaOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.schemaOnly) { _, newVal in
                            if newVal { viewModel.dataOnly = false }
                        }
                }

                PropertyRow(
                    title: "Data Only",
                    info: "Dump only the table data, not the schema. The target database must already have the tables."
                ) {
                    Toggle("", isOn: $viewModel.dataOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.dataOnly) { _, newVal in
                            if newVal { viewModel.schemaOnly = false }
                        }
                }

                PropertyRow(
                    title: "Include Blobs",
                    info: "Include large objects (BLOBs) in the dump. Enabled by default. Disable to exclude large objects and reduce dump size."
                ) {
                    Toggle("", isOn: $viewModel.includeBlobs)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section {
                PropertyRow(
                    title: "Include Tables",
                    info: "Comma-separated list of table patterns to include. Supports wildcards (*). Example: public.users, public.orders*"
                ) {
                    TextField("", text: $viewModel.includeTables, prompt: Text("e.g. public.users, public.orders*"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Exclude Tables",
                    info: "Comma-separated list of table patterns to exclude."
                ) {
                    TextField("", text: $viewModel.excludeTables, prompt: Text("e.g. public.temp_*"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Include Schemas",
                    info: "Comma-separated list of schema patterns to include."
                ) {
                    TextField("", text: $viewModel.includeSchemas, prompt: Text("e.g. public, app"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Exclude Schemas",
                    info: "Comma-separated list of schema patterns to exclude."
                ) {
                    TextField("", text: $viewModel.excludeSchemas, prompt: Text("e.g. pg_catalog"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Exclude Table Data",
                    info: "Comma-separated list of tables whose data should be excluded (schema is still dumped)."
                ) {
                    TextField("", text: $viewModel.excludeTableData, prompt: Text("e.g. public.audit_log"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }
            } header: {
                Text("Filters")
            } footer: {
                Text("Use comma-separated patterns. Wildcards (*) are supported.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}
