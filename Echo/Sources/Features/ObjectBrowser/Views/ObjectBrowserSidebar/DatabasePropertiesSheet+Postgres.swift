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
                applyPgAlter { admin in
                    try await admin.alterDatabaseOwner(name: databaseName, newOwner: newOwner)
                }
            }

            LabeledContent("Description") {
                TextField("", text: $pgComment, axis: .vertical)
                    .lineLimit(1...3)
                    .onSubmit {
                        applyPgAlter { admin in
                            try await admin.commentOnDatabase(name: databaseName, comment: pgComment.isEmpty ? nil : pgComment)
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
                        applyPgAlter { admin in
                            try await admin.alterDatabaseTablespace(name: databaseName, tablespace: newValue)
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
                            applyPgAlter { admin in
                                try await admin.alterDatabaseConnectionLimit(name: databaseName, limit: pgConnectionLimit)
                            }
                        }
                    Text("-1 = unlimited")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.tertiary)
                }
            }

            Toggle("Is Template", isOn: $pgIsTemplate)
                .onChange(of: pgIsTemplate) { _, v in
                    applyPgAlter { admin in
                        try await admin.alterDatabaseIsTemplate(name: databaseName, isTemplate: v)
                    }
                }

            Toggle("Allow Connections", isOn: $pgAllowConnections)
                .onChange(of: pgAllowConnections) { _, v in
                    applyPgAlter { admin in
                        try await admin.alterDatabaseAllowConnections(name: databaseName, allow: v)
                    }
                }
        }
    }

    @ViewBuilder
    func postgresParametersPage() -> some View {
        if pgParams.isEmpty {
            Section {
                Text("No database-level parameters configured.")
                    .foregroundStyle(.secondary)
                    .font(TypographyTokens.standard)
            }
        } else {
            Section("Database Parameters") {
                ForEach(Array(pgParams.enumerated()), id: \.offset) { _, param in
                    LabeledContent(param.name, value: param.value)
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

        if let acl = props.acl, !acl.isEmpty {
            Section("Privileges") {
                Text(acl)
                    .font(TypographyTokens.monospaced)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - PostgreSQL Apply Alter

    func applyPgAlter(_ action: @Sendable @escaping (PostgresAdmin) async throws -> Void) {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client
        let logger = pgSession.logger
        isSaving = true
        statusMessage = nil

        Task {
            do {
                let admin = PostgresAdmin(client: client, logger: logger)
                try await action(admin)
                isSaving = false
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            } catch {
                isSaving = false
                statusMessage = error.localizedDescription
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: error.localizedDescription, style: .error)
            }
        }
    }

    // MARK: - PostgreSQL Data Loading

    func loadPostgresProperties() async throws {
        guard let pgSession = session.session as? PostgresSession else { return }
        let admin = PostgresAdmin(client: pgSession.client, logger: pgSession.logger)
        let metadata = PostgresMetadata()

        let props = try await admin.fetchDatabaseProperties(name: databaseName, using: pgSession.client)
        pgProps = props
        pgOwner = props.owner
        pgConnectionLimit = props.connectionLimit
        pgIsTemplate = props.isTemplate
        pgAllowConnections = props.allowConnections
        pgComment = props.description ?? ""

        pgParams = (try? await admin.fetchDatabaseParameters(databaseOid: props.oid, using: pgSession.client)) ?? []

        let roles = try await metadata.listRoles(using: pgSession.client)
        pgRoles = roles.map(\.name).sorted()

        pgTablespaces = (try? await admin.listTablespaces(using: pgSession.client)) ?? ["pg_default"]
    }
}
