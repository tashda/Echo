import SwiftUI
import PostgresKit

// MARK: - PostgreSQL General & Definition Pages

extension DatabaseEditorView {

    @ViewBuilder
    func postgresGeneralPage(_ props: PostgresDatabaseProperties) -> some View {
        Section("Information") {
            PropertyRow(title: "Name") {
                Text(props.name)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "OID") {
                Text(props.oid)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Owner") {
                Picker("", selection: $viewModel.pgOwner) {
                    ForEach(viewModel.pgRoles, id: \.self) { role in
                        Text(role).tag(role)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: viewModel.pgOwner) { _, newOwner in
                let dbName = viewModel.databaseName
                Task {
                    await viewModel.applyPgAlter(session: session, message: "Owner changed to \(newOwner).") { client in
                        try await client.admin.alterDatabaseOwner(name: dbName, newOwner: newOwner)
                    }
                }
            }

            PropertyRow(title: "Description") {
                TextField("", text: $viewModel.pgComment, prompt: Text("Optional comment"), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        let dbName = viewModel.databaseName
                        let comment = viewModel.pgComment
                        Task {
                            await viewModel.applyPgAlter(session: session, message: "Description updated.") { client in
                                try await client.admin.addDatabaseComment(name: dbName, comment: comment.isEmpty ? nil : comment)
                            }
                        }
                    }
            }
        }

        Section("Statistics") {
            PropertyRow(title: "Database Size") {
                Text(ByteCountFormatter.string(fromByteCount: props.sizeBytes, countStyle: .file))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Active Connections") {
                Text("\(props.activeConnections)")
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

    @ViewBuilder
    func postgresDefinitionPage(_ props: PostgresDatabaseProperties) -> some View {
        Section("Character Set") {
            PropertyRow(title: "Encoding") {
                Text(props.encoding)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Collation") {
                Text(props.collation)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Character Type") {
                Text(props.ctype)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            if let icu = props.icuLocale {
                PropertyRow(title: "ICU Locale") {
                    Text(icu)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        Section("Tablespace") {
            if viewModel.pgTablespaces.count > 1 {
                PropertyRow(title: "Tablespace") {
                    let dbName = viewModel.databaseName
                    Picker("", selection: Binding(
                        get: { props.tablespace },
                        set: { newValue in
                            Task {
                                await viewModel.applyPgAlter(session: session, message: "Tablespace changed to \(newValue).") { client in
                                    try await client.admin.alterDatabaseTablespace(name: dbName, tablespace: newValue)
                                }
                            }
                        }
                    )) {
                        ForEach(viewModel.pgTablespaces, id: \.self) { ts in
                            Text(ts).tag(ts)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            } else {
                PropertyRow(title: "Tablespace") {
                    Text(props.tablespace)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        Section("Connection") {
            PropertyRow(
                title: "Connection Limit",
                subtitle: "-1 = unlimited"
            ) {
                TextField("", value: $viewModel.pgConnectionLimit, format: .number, prompt: Text("-1 for unlimited"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        let dbName = viewModel.databaseName
                        let limit = viewModel.pgConnectionLimit
                        Task {
                            await viewModel.applyPgAlter(session: session, message: "Connection limit updated.") { client in
                                try await client.admin.alterDatabaseConnectionLimit(name: dbName, limit: limit)
                            }
                        }
                    }
            }

            PropertyRow(title: "Is Template") {
                Toggle("", isOn: $viewModel.pgIsTemplate)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: viewModel.pgIsTemplate) { _, v in
                        let dbName = viewModel.databaseName
                        Task {
                            await viewModel.applyPgAlter(session: session, message: "Is Template set to \(v).") { client in
                                try await client.admin.alterDatabaseIsTemplate(name: dbName, isTemplate: v)
                            }
                        }
                    }
            }

            PropertyRow(title: "Allow Connections") {
                Toggle("", isOn: $viewModel.pgAllowConnections)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: viewModel.pgAllowConnections) { _, v in
                        let dbName = viewModel.databaseName
                        Task {
                            await viewModel.applyPgAlter(session: session, message: "Allow Connections set to \(v).") { client in
                                try await client.admin.alterDatabaseAllowConnections(name: dbName, allow: v)
                            }
                        }
                    }
            }
        }
    }
}
