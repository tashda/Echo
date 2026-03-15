import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Pages

extension DatabasePropertiesSheet {

    @ViewBuilder
    func postgresGeneralPage(_ props: PostgresDatabaseProperties) -> some View {
        Section("Information") {
            LabeledContent("Name", value: props.name)
            LabeledContent("OID", value: props.oid)

            Picker("Owner", selection: $pgOwner) {
                ForEach(pgRoles, id: \.self) { role in
                    Text(role).tag(role)
                }
            }
            .onChange(of: pgOwner) { _, newOwner in
                applyPgAlter { client in
                    try await client.admin.alterDatabaseOwner(name: databaseName, newOwner: newOwner)
                }
            }

            LabeledContent("Description") {
                TextField("", text: $pgComment, axis: .vertical)
                    .lineLimit(1...3)
                    .onSubmit {
                        applyPgAlter { client in
                            try await client.admin.addDatabaseComment(name: databaseName, comment: pgComment.isEmpty ? nil : pgComment)
                        }
                    }
            }
        }

        if let version = session.databaseStructure?.serverVersion {
            Section("Server") {
                LabeledContent("Version", value: version)
            }
        }
    }

    @ViewBuilder
    func postgresDefinitionPage(_ props: PostgresDatabaseProperties) -> some View {
        Section("Character Set") {
            LabeledContent("Encoding", value: props.encoding)
            LabeledContent("Collation", value: props.collation)
            LabeledContent("Character Type", value: props.ctype)
            if let icu = props.icuLocale {
                LabeledContent("ICU Locale", value: icu)
            }
        }

        Section("Tablespace") {
            if pgTablespaces.count > 1 {
                Picker("Tablespace", selection: Binding(
                    get: { props.tablespace },
                    set: { newValue in
                        applyPgAlter { client in
                            try await client.admin.alterDatabaseTablespace(name: databaseName, tablespace: newValue)
                        }
                    }
                )) {
                    ForEach(pgTablespaces, id: \.self) { ts in
                        Text(ts).tag(ts)
                    }
                }
            } else {
                LabeledContent("Tablespace", value: props.tablespace)
            }
        }

        Section("Connection") {
            LabeledContent("Connection Limit") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $pgConnectionLimit, format: .number)
                        .frame(width: 60)
                        .onSubmit {
                            applyPgAlter { client in
                                try await client.admin.alterDatabaseConnectionLimit(name: databaseName, limit: pgConnectionLimit)
                            }
                        }
                    Text("-1 = unlimited")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            Toggle("Is Template", isOn: $pgIsTemplate)
                .onChange(of: pgIsTemplate) { _, v in
                    applyPgAlter { client in
                        try await client.admin.alterDatabaseIsTemplate(name: databaseName, isTemplate: v)
                    }
                }

            Toggle("Allow Connections", isOn: $pgAllowConnections)
                .onChange(of: pgAllowConnections) { _, v in
                    applyPgAlter { client in
                        try await client.admin.alterDatabaseAllowConnections(name: databaseName, allow: v)
                    }
                }
        }
    }

    @ViewBuilder
    func postgresStatisticsPage(_ props: PostgresDatabaseProperties) -> some View {
        Section("Size") {
            LabeledContent("Database Size", value: ByteCountFormatter.string(fromByteCount: props.sizeBytes, countStyle: .file))
            LabeledContent("Size (bytes)", value: "\(props.sizeBytes)")
        }

        Section("Connections") {
            LabeledContent("Active Connections", value: "\(props.activeConnections)")
        }
    }

    // MARK: - PostgreSQL Apply Alter

    func applyPgAlter(_ action: @Sendable @escaping (PostgresKit.PostgresClient) async throws -> Void) {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client
        isSaving = true
        statusMessage = nil

        Task {
            do {
                try await action(client)
                isSaving = false
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

        let props = try await client.introspection.fetchDatabaseProperties(name: databaseName)
        pgProps = props
        pgOwner = props.owner
        pgConnectionLimit = props.connectionLimit
        pgIsTemplate = props.isTemplate
        pgAllowConnections = props.allowConnections
        pgComment = props.description ?? ""

        pgParams = (try? await client.introspection.fetchDatabaseParameters(databaseOid: props.oid)) ?? []

        let roles = (try? await client.security.listRoles()) ?? []
        pgRoles = roles.map(\.name).sorted()

        pgTablespaces = (try? await client.introspection.listTablespaces()) ?? ["pg_default"]

        pgSettingDefinitions = (try? await client.introspection.fetchDatabaseConfigurableSettings()) ?? []

        if let acl = props.acl {
            pgACLEntries = PostgresACLEntry.parse(acl: acl)
        }

        pgDefaultPrivileges = (try? await client.introspection.fetchDefaultPrivileges()) ?? []

        let schemas = (try? await client.introspection.listSchemas()) ?? []
        pgSchemas = schemas.map(\.name).sorted()
    }
}
