import SwiftUI
import PostgresKit
import SQLServerKit

/// Sheet displaying database properties, modeled after SSMS / pgAdmin properties dialogs.
/// MSSQL options are editable via pickers and toggles; changes are applied immediately.
struct DatabasePropertiesSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    // Read-only sections (PostgreSQL, fallback)
    @State private var readOnlySections: [PropertySection] = []

    // MSSQL editable state
    @State private var mssqlProps: SQLServerDatabaseProperties?
    @State private var recoveryModel: SQLServerDatabaseOption.RecoveryModel = .full
    @State private var compatibilityLevel: Int = 160
    @State private var isReadOnly = false
    @State private var userAccess: SQLServerDatabaseOption.UserAccessOption = .multiUser
    @State private var pageVerify: SQLServerDatabaseOption.PageVerifyOption = .checksum
    @State private var autoClose = false
    @State private var autoShrink = false
    @State private var autoCreateStats = true
    @State private var autoUpdateStats = true

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var statusMessage: String?

    private var isMSSQL: Bool { session.connection.databaseType == .microsoftSQL }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if isLoading {
                    Section {
                        HStack(spacing: SpacingTokens.xs) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading properties\u{2026}")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                } else if isMSSQL, let props = mssqlProps {
                    mssqlGeneralSection(props)
                    mssqlOptionsSection(props)
                    mssqlAutomaticSection()
                    mssqlServerSection()
                } else {
                    ForEach(readOnlySections) { section in
                        Section(section.title) {
                            ForEach(section.rows) { row in
                                LabeledContent(row.label, value: row.value)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                if let status = statusMessage {
                    Text(status)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(SpacingTokens.md2)
        }
        .frame(minWidth: 500, minHeight: 420)
        .task { await loadProperties() }
    }

    // MARK: - MSSQL Editable Sections

    @ViewBuilder
    private func mssqlGeneralSection(_ props: SQLServerDatabaseProperties) -> some View {
        Section("General") {
            LabeledContent("Name", value: props.name)
            LabeledContent("Owner", value: props.owner)
            LabeledContent("Status", value: props.stateDescription)
            LabeledContent("Date Created", value: props.createDate)
            LabeledContent("Size", value: String(format: "%.2f MB", props.sizeMB))
            LabeledContent("Active Sessions", value: "\(props.activeSessions)")
            LabeledContent("Collation", value: props.collationName)
        }
    }

    @ViewBuilder
    private func mssqlOptionsSection(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Options") {
            Picker("Recovery Model", selection: $recoveryModel) {
                ForEach(SQLServerDatabaseOption.RecoveryModel.allCases, id: \.self) { model in
                    Text(model.rawValue).tag(model)
                }
            }
            .onChange(of: recoveryModel) { _, newValue in
                applyOption(.recoveryModel(newValue))
            }

            Picker("Compatibility Level", selection: $compatibilityLevel) {
                ForEach(compatibilityLevels, id: \.value) { level in
                    Text(level.label).tag(level.value)
                }
            }
            .onChange(of: compatibilityLevel) { _, newValue in
                applyOption(.compatibilityLevel(newValue))
            }

            Toggle("Read Only", isOn: $isReadOnly)
                .onChange(of: isReadOnly) { _, newValue in
                    applyOption(.readOnly(newValue))
                }

            Picker("User Access", selection: $userAccess) {
                ForEach(SQLServerDatabaseOption.UserAccessOption.allCases, id: \.self) { opt in
                    Text(opt.displayName).tag(opt)
                }
            }
            .onChange(of: userAccess) { _, newValue in
                applyOption(.userAccess(newValue))
            }

            Picker("Page Verify", selection: $pageVerify) {
                ForEach(SQLServerDatabaseOption.PageVerifyOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .onChange(of: pageVerify) { _, newValue in
                applyOption(.pageVerify(newValue))
            }
        }
    }

    @ViewBuilder
    private func mssqlAutomaticSection() -> some View {
        Section("Automatic") {
            Toggle("Auto Close", isOn: $autoClose)
                .onChange(of: autoClose) { _, newValue in
                    applyOption(.autoClose(newValue))
                }

            Toggle("Auto Shrink", isOn: $autoShrink)
                .onChange(of: autoShrink) { _, newValue in
                    applyOption(.autoShrink(newValue))
                }

            Toggle("Auto Create Statistics", isOn: $autoCreateStats)
                .onChange(of: autoCreateStats) { _, newValue in
                    applyOption(.autoCreateStatistics(newValue))
                }

            Toggle("Auto Update Statistics", isOn: $autoUpdateStats)
                .onChange(of: autoUpdateStats) { _, newValue in
                    applyOption(.autoUpdateStatistics(newValue))
                }
        }
    }

    @ViewBuilder
    private func mssqlServerSection() -> some View {
        if let version = session.databaseStructure?.serverVersion {
            Section("Server") {
                LabeledContent("Version", value: version)
            }
        }
    }

    // MARK: - Apply Option

    private func applyOption(_ option: SQLServerDatabaseOption) {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.makeAdministrationClient()
        isSaving = true
        statusMessage = nil

        Task {
            do {
                let messages = try await admin.alterDatabaseOption(name: databaseName, option: option)
                let info = messages.filter { $0.kind == .info }.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    isSaving = false
                    if !info.isEmpty {
                        statusMessage = info
                    }
                    // Refresh sidebar state
                    Task { await environmentState.refreshDatabaseStructure(for: session.id) }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    statusMessage = error.localizedDescription
                    environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: error.localizedDescription, style: .error)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadProperties() async {
        do {
            switch session.connection.databaseType {
            case .postgresql:
                readOnlySections = try await loadPostgresProperties()
            case .microsoftSQL:
                try await loadMSSQLProperties()
            default:
                readOnlySections = [PropertySection(title: "General", rows: [
                    .init(label: "Name", value: databaseName),
                    .init(label: "Type", value: session.connection.databaseType.rawValue)
                ])]
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - PostgreSQL (read-only)

    private func loadPostgresProperties() async throws -> [PropertySection] {
        guard let pgSession = session.session as? PostgresSession else {
            return [generalFallbackSection()]
        }

        let sql = """
            SELECT
                d.datname AS name,
                pg_catalog.pg_get_userbyid(d.datdba) AS owner,
                pg_catalog.pg_encoding_to_char(d.encoding) AS encoding,
                d.datcollate AS collation,
                d.datctype AS ctype,
                d.datconnlimit AS connection_limit,
                d.datistemplate AS is_template,
                d.datallowconn AS allow_connections,
                pg_catalog.pg_tablespace_name(d.dattablespace) AS tablespace,
                pg_catalog.pg_database_size(d.datname) AS size_bytes,
                (SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE datname = d.datname) AS active_connections
            FROM pg_catalog.pg_database d
            WHERE d.datname = '\(databaseName.replacingOccurrences(of: "'", with: "''"))'
            """

        let result = try await pgSession.simpleQuery(sql)

        guard let row = result.rows.first else {
            return [generalFallbackSection()]
        }

        func col(_ i: Int, fallback: String = "Unknown") -> String {
            guard i < row.count, let v = row[i], !v.isEmpty else { return fallback }
            return v
        }

        let sizeBytes = Int(col(9, fallback: "0")) ?? 0
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)

        var sections: [PropertySection] = []

        sections.append(PropertySection(title: "General", rows: [
            .init(label: "Name", value: col(0, fallback: databaseName)),
            .init(label: "Owner", value: col(1)),
            .init(label: "Size", value: sizeFormatted),
            .init(label: "Active Connections", value: col(10, fallback: "0")),
            .init(label: "Tablespace", value: col(8, fallback: "pg_default")),
        ]))

        let connLimit = col(5, fallback: "-1")
        let isTemplate = col(6, fallback: "false")
        let allowConn = col(7, fallback: "true")

        sections.append(PropertySection(title: "Definition", rows: [
            .init(label: "Encoding", value: col(2)),
            .init(label: "Collation", value: col(3)),
            .init(label: "Character Type", value: col(4)),
            .init(label: "Connection Limit", value: connLimit == "-1" ? "Unlimited" : connLimit),
            .init(label: "Is Template", value: isTemplate == "t" || isTemplate == "true" ? "Yes" : "No"),
            .init(label: "Allow Connections", value: allowConn == "t" || allowConn == "true" ? "Yes" : "No"),
        ]))

        let admin = PostgresAdmin(client: pgSession.client, logger: pgSession.logger)
        if let version = try? await admin.show("server_version") {
            sections.append(PropertySection(title: "Server", rows: [
                .init(label: "Version", value: version),
            ]))
        }

        return sections
    }

    // MARK: - Microsoft SQL Server

    private func loadMSSQLProperties() async throws {
        guard let mssqlSession = session.session as? MSSQLSession else {
            readOnlySections = [generalFallbackSection()]
            return
        }

        let admin = mssqlSession.makeAdministrationClient()
        let props = try await admin.fetchDatabaseProperties(name: databaseName)
        mssqlProps = props

        // Populate editable state from fetched properties
        recoveryModel = SQLServerDatabaseOption.RecoveryModel(rawValue: props.recoveryModel) ?? .full
        compatibilityLevel = props.compatibilityLevel
        isReadOnly = props.isReadOnly
        userAccess = SQLServerDatabaseOption.UserAccessOption.fromDescription(props.userAccessDescription)
        pageVerify = SQLServerDatabaseOption.PageVerifyOption(rawValue: props.pageVerifyOption) ?? .checksum
        autoClose = props.isAutoCloseOn
        autoShrink = props.isAutoShrinkOn
        autoCreateStats = props.isAutoCreateStatsOn
        autoUpdateStats = props.isAutoUpdateStatsOn
    }

    // MARK: - Fallback

    private func generalFallbackSection() -> PropertySection {
        PropertySection(title: "General", rows: [
            .init(label: "Name", value: databaseName),
            .init(label: "Type", value: session.connection.databaseType.rawValue),
        ])
    }

    // MARK: - Compatibility Levels

    private var compatibilityLevels: [(label: String, value: Int)] {
        [
            ("SQL Server 2022 (160)", 160),
            ("SQL Server 2019 (150)", 150),
            ("SQL Server 2017 (140)", 140),
            ("SQL Server 2016 (130)", 130),
            ("SQL Server 2014 (120)", 120),
            ("SQL Server 2012 (110)", 110),
            ("SQL Server 2008 (100)", 100),
        ]
    }
}

// MARK: - Display Helpers

extension SQLServerDatabaseOption.UserAccessOption {
    var displayName: String {
        switch self {
        case .multiUser: "Multi User"
        case .singleUser: "Single User"
        case .restrictedUser: "Restricted User"
        }
    }

    static func fromDescription(_ desc: String) -> Self {
        switch desc.uppercased() {
        case "SINGLE_USER": return .singleUser
        case "RESTRICTED_USER": return .restrictedUser
        default: return .multiUser
        }
    }
}

// MARK: - Models

struct PropertySection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [PropertyRow]
}

struct PropertyRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}
