import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Pages

extension DatabasePropertiesSheet {

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
                Picker("", selection: $pgOwner) {
                    ForEach(pgRoles, id: \.self) { role in
                        Text(role).tag(role)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: pgOwner) { _, newOwner in
                applyPgAlter(message: "Owner changed to \(newOwner).") { client in
                    try await client.admin.alterDatabaseOwner(name: databaseName, newOwner: newOwner)
                }
            }

            PropertyRow(title: "Description") {
                TextField("", text: $pgComment, prompt: Text("Optional comment"), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        applyPgAlter(message: "Description updated.") { client in
                            try await client.admin.addDatabaseComment(name: databaseName, comment: pgComment.isEmpty ? nil : pgComment)
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
            if pgTablespaces.count > 1 {
                PropertyRow(title: "Tablespace") {
                    Picker("", selection: Binding(
                        get: { props.tablespace },
                        set: { newValue in
                            applyPgAlter(message: "Tablespace changed to \(newValue).") { client in
                                try await client.admin.alterDatabaseTablespace(name: databaseName, tablespace: newValue)
                            }
                        }
                    )) {
                        ForEach(pgTablespaces, id: \.self) { ts in
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
                TextField("", value: $pgConnectionLimit, format: .number, prompt: Text("-1 for unlimited"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        applyPgAlter(message: "Connection limit updated.") { client in
                            try await client.admin.alterDatabaseConnectionLimit(name: databaseName, limit: pgConnectionLimit)
                        }
                    }
            }

            PropertyRow(title: "Is Template") {
                Toggle("", isOn: $pgIsTemplate)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: pgIsTemplate) { _, v in
                        applyPgAlter(message: "Is Template set to \(v).") { client in
                            try await client.admin.alterDatabaseIsTemplate(name: databaseName, isTemplate: v)
                        }
                    }
            }

            PropertyRow(title: "Allow Connections") {
                Toggle("", isOn: $pgAllowConnections)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: pgAllowConnections) { _, v in
                        applyPgAlter(message: "Allow Connections set to \(v).") { client in
                            try await client.admin.alterDatabaseAllowConnections(name: databaseName, allow: v)
                        }
                    }
            }
        }
    }

    // MARK: - PostgreSQL Apply Alter

    func applyPgAlter(
        message: String = "Database properties updated.",
        _ action: @Sendable @escaping (PostgresKit.PostgresClient) async throws -> Void
    ) {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client
        isSaving = true
        statusMessage = nil

        Task {
            do {
                try await action(client)
                isSaving = false
                environmentState.notificationEngine?.post(category: .databasePropertiesSaved, message: message)
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            } catch {
                isSaving = false
                statusMessage = error.localizedDescription
                environmentState.notificationEngine?.post(category: .databasePropertiesError, message: error.localizedDescription)
            }
        }
    }

    // MARK: - PostgreSQL Data Loading

    func loadPostgresProperties() async throws {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client

        let props = try await client.metadata.fetchDatabaseProperties(name: databaseName)
        pgProps = props
        pgOwner = props.owner
        pgConnectionLimit = props.connectionLimit
        pgIsTemplate = props.isTemplate
        pgAllowConnections = props.allowConnections
        pgComment = props.description ?? ""

        pgParams = (try? await client.metadata.fetchDatabaseParameters(databaseOid: props.oid)) ?? []
        pgOriginalParams = pgParams

        let roles = (try? await client.security.listRoles()) ?? []
        pgRoles = roles.map(\.name).sorted()

        pgTablespaces = (try? await client.metadata.listTablespaces()) ?? ["pg_default"]

        pgSettingDefinitions = (try? await client.metadata.fetchDatabaseConfigurableSettings()) ?? []

        if let acl = props.acl {
            pgACLEntries = PostgresACLEntry.parse(acl: acl)
        }

        pgDefaultPrivileges = (try? await client.metadata.fetchDefaultPrivileges()) ?? []
        pgOriginalDefaultPrivileges = pgDefaultPrivileges

        let schemas = (try? await client.metadata.listSchemas()) ?? []
        pgSchemas = schemas.map(\.name).sorted()
    }
}
