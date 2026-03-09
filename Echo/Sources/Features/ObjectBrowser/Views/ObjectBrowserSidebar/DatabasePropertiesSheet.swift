import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Database Properties Sheet

/// Settings-style database properties panel with sidebar categories and detail pane.
/// Modeled after macOS System Settings: category list on the left, grouped form on the right.
struct DatabasePropertiesSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var selectedPage: PropertiesPage = .general
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var statusMessage: String?

    // MSSQL state
    @State private var mssqlProps: SQLServerDatabaseProperties?
    @State private var mssqlFiles: [SQLServerDatabaseFile] = []
    @State private var recoveryModel: SQLServerDatabaseOption.RecoveryModel = .full
    @State private var compatibilityLevel: Int = 160
    @State private var isReadOnly = false
    @State private var userAccess: SQLServerDatabaseOption.UserAccessOption = .multiUser
    @State private var pageVerify: SQLServerDatabaseOption.PageVerifyOption = .checksum
    @State private var targetRecoveryTime: Int = 0
    @State private var delayedDurability: SQLServerDatabaseOption.DelayedDurabilityOption = .disabled
    @State private var allowSnapshotIsolation = false
    @State private var readCommittedSnapshot = false
    @State private var isEncrypted = false
    @State private var isBrokerEnabled = false
    @State private var isTrustworthy = false
    @State private var parameterization: SQLServerDatabaseOption.ParameterizationOption = .simple
    @State private var autoClose = false
    @State private var autoShrink = false
    @State private var autoCreateStats = true
    @State private var autoUpdateStats = true
    @State private var autoUpdateStatsAsync = false
    @State private var ansiNullDefault = false
    @State private var ansiNulls = false
    @State private var ansiPadding = false
    @State private var ansiWarnings = false
    @State private var arithAbort = false
    @State private var concatNullYieldsNull = false
    @State private var quotedIdentifier = false
    @State private var recursiveTriggers = false
    @State private var numericRoundAbort = false
    @State private var dateCorrelation = false

    // PostgreSQL state
    @State private var pgProps: PostgresDatabaseProperties?
    @State private var pgParams: [PostgresDatabaseParameter] = []
    @State private var pgRoles: [String] = []
    @State private var pgTablespaces: [String] = []
    @State private var pgOwner: String = ""
    @State private var pgConnectionLimit: Int = -1
    @State private var pgIsTemplate = false
    @State private var pgAllowConnections = true
    @State private var pgComment: String = ""

    private var isMSSQL: Bool { session.connection.databaseType == .microsoftSQL }
    private var isPostgres: Bool { session.connection.databaseType == .postgresql }

    private var pages: [PropertiesPage] {
        if isMSSQL {
            return [.general, .options, .automatic, .ansi, .files]
        } else if isPostgres {
            return [.general, .definition, .parameters, .statistics]
        } else {
            return [.general]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: 180)

                Divider()

                // Detail pane
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // Bottom bar
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
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 680, minHeight: 480)
        .frame(idealWidth: 720, idealHeight: 540)
        .task { await loadProperties() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(pages, id: \.self, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading properties\u{2026}")
                Spacer()
            }
        } else if let error = errorMessage {
            VStack {
                Spacer()
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        } else {
            Form {
                pageContent
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            if isMSSQL, let props = mssqlProps {
                mssqlGeneralPage(props)
            } else if isPostgres, let props = pgProps {
                postgresGeneralPage(props)
            }
        case .options:
            if isMSSQL, let props = mssqlProps {
                mssqlOptionsPage(props)
            }
        case .automatic:
            if isMSSQL {
                mssqlAutomaticPage()
            }
        case .ansi:
            if isMSSQL {
                mssqlAnsiPage()
            }
        case .files:
            if isMSSQL {
                mssqlFilesPage()
            }
        case .definition:
            if isPostgres, let props = pgProps {
                postgresDefinitionPage(props)
            }
        case .parameters:
            if isPostgres {
                postgresParametersPage()
            }
        case .statistics:
            if isPostgres, let props = pgProps {
                postgresStatisticsPage(props)
            }
        }
    }

    // MARK: - MSSQL Pages

    @ViewBuilder
    private func mssqlGeneralPage(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Information") {
            LabeledContent("Name", value: props.name)
            LabeledContent("Owner", value: props.owner)
            LabeledContent("Status", value: props.stateDescription)
            LabeledContent("Date Created", value: props.createDate)
            LabeledContent("Size", value: String(format: "%.2f MB", props.sizeMB))
            LabeledContent("Active Sessions", value: "\(props.activeSessions)")
            LabeledContent("Collation", value: props.collationName)
        }

        Section("Backup") {
            LabeledContent("Last Database Backup", value: props.lastBackupDate ?? "Never")
            LabeledContent("Last Log Backup", value: props.lastLogBackupDate ?? "Never")
        }

        if let version = session.databaseStructure?.serverVersion {
            Section("Server") {
                LabeledContent("Version", value: version)
            }
        }
    }

    @ViewBuilder
    private func mssqlOptionsPage(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Recovery") {
            Picker("Recovery Model", selection: $recoveryModel) {
                ForEach(SQLServerDatabaseOption.RecoveryModel.allCases, id: \.self) { model in
                    Text(model.rawValue).tag(model)
                }
            }
            .onChange(of: recoveryModel) { _, v in applyMSSQLOption(.recoveryModel(v)) }

            Picker("Page Verify", selection: $pageVerify) {
                ForEach(SQLServerDatabaseOption.PageVerifyOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .onChange(of: pageVerify) { _, v in applyMSSQLOption(.pageVerify(v)) }

            // Target Recovery Time is an integer field in seconds
            LabeledContent("Target Recovery Time") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $targetRecoveryTime, format: .number)
                        .frame(width: 60)
                        .onSubmit { applyMSSQLOption(.targetRecoveryTime(targetRecoveryTime)) }
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Delayed Durability", selection: $delayedDurability) {
                ForEach(SQLServerDatabaseOption.DelayedDurabilityOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .onChange(of: delayedDurability) { _, v in applyMSSQLOption(.delayedDurability(v)) }
        }

        Section("Compatibility") {
            Picker("Compatibility Level", selection: $compatibilityLevel) {
                ForEach(compatibilityLevels, id: \.value) { level in
                    Text(level.label).tag(level.value)
                }
            }
            .onChange(of: compatibilityLevel) { _, v in applyMSSQLOption(.compatibilityLevel(v)) }
        }

        Section("State") {
            Toggle("Read Only", isOn: $isReadOnly)
                .onChange(of: isReadOnly) { _, v in applyMSSQLOption(.readOnly(v)) }

            Picker("User Access", selection: $userAccess) {
                ForEach(SQLServerDatabaseOption.UserAccessOption.allCases, id: \.self) { opt in
                    Text(opt.displayName).tag(opt)
                }
            }
            .onChange(of: userAccess) { _, v in applyMSSQLOption(.userAccess(v)) }

            Toggle("Encryption", isOn: $isEncrypted)
                .onChange(of: isEncrypted) { _, v in applyMSSQLOption(.encryption(v)) }
        }

        Section("Isolation") {
            Toggle("Allow Snapshot Isolation", isOn: $allowSnapshotIsolation)
                .onChange(of: allowSnapshotIsolation) { _, v in applyMSSQLOption(.allowSnapshotIsolation(v)) }

            Toggle("Read Committed Snapshot", isOn: $readCommittedSnapshot)
                .onChange(of: readCommittedSnapshot) { _, v in applyMSSQLOption(.readCommittedSnapshot(v)) }
        }

        Section("Miscellaneous") {
            Toggle("Broker Enabled", isOn: $isBrokerEnabled)
                .onChange(of: isBrokerEnabled) { _, v in applyMSSQLOption(.brokerEnabled(v)) }

            Toggle("Trustworthy", isOn: $isTrustworthy)
                .onChange(of: isTrustworthy) { _, v in applyMSSQLOption(.trustworthy(v)) }

            Picker("Parameterization", selection: $parameterization) {
                ForEach(SQLServerDatabaseOption.ParameterizationOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .onChange(of: parameterization) { _, v in applyMSSQLOption(.parameterization(v)) }
        }
    }

    @ViewBuilder
    private func mssqlAutomaticPage() -> some View {
        Section("Statistics") {
            Toggle("Auto Create Statistics", isOn: $autoCreateStats)
                .onChange(of: autoCreateStats) { _, v in applyMSSQLOption(.autoCreateStatistics(v)) }

            Toggle("Auto Update Statistics", isOn: $autoUpdateStats)
                .onChange(of: autoUpdateStats) { _, v in applyMSSQLOption(.autoUpdateStatistics(v)) }

            Toggle("Auto Update Statistics Asynchronously", isOn: $autoUpdateStatsAsync)
                .onChange(of: autoUpdateStatsAsync) { _, v in applyMSSQLOption(.autoUpdateStatisticsAsync(v)) }
        }

        Section("Storage") {
            Toggle("Auto Close", isOn: $autoClose)
                .onChange(of: autoClose) { _, v in applyMSSQLOption(.autoClose(v)) }

            Toggle("Auto Shrink", isOn: $autoShrink)
                .onChange(of: autoShrink) { _, v in applyMSSQLOption(.autoShrink(v)) }
        }
    }

    @ViewBuilder
    private func mssqlAnsiPage() -> some View {
        Section("ANSI Defaults") {
            Toggle("ANSI NULL Default", isOn: $ansiNullDefault)
                .onChange(of: ansiNullDefault) { _, v in applyMSSQLOption(.ansiNullDefault(v)) }

            Toggle("ANSI NULLS Enabled", isOn: $ansiNulls)
                .onChange(of: ansiNulls) { _, v in applyMSSQLOption(.ansiNulls(v)) }

            Toggle("ANSI Padding Enabled", isOn: $ansiPadding)
                .onChange(of: ansiPadding) { _, v in applyMSSQLOption(.ansiPadding(v)) }

            Toggle("ANSI Warnings Enabled", isOn: $ansiWarnings)
                .onChange(of: ansiWarnings) { _, v in applyMSSQLOption(.ansiWarnings(v)) }
        }

        Section("Arithmetic") {
            Toggle("Arithmetic Abort Enabled", isOn: $arithAbort)
                .onChange(of: arithAbort) { _, v in applyMSSQLOption(.arithAbort(v)) }

            Toggle("Numeric Round-Abort", isOn: $numericRoundAbort)
                .onChange(of: numericRoundAbort) { _, v in applyMSSQLOption(.numericRoundAbort(v)) }

            Toggle("Concatenate Null Yields Null", isOn: $concatNullYieldsNull)
                .onChange(of: concatNullYieldsNull) { _, v in applyMSSQLOption(.concatNullYieldsNull(v)) }
        }

        Section("Identifiers & Triggers") {
            Toggle("Quoted Identifiers Enabled", isOn: $quotedIdentifier)
                .onChange(of: quotedIdentifier) { _, v in applyMSSQLOption(.quotedIdentifier(v)) }

            Toggle("Recursive Triggers Enabled", isOn: $recursiveTriggers)
                .onChange(of: recursiveTriggers) { _, v in applyMSSQLOption(.recursiveTriggers(v)) }

            Toggle("Date Correlation Optimization", isOn: $dateCorrelation)
                .onChange(of: dateCorrelation) { _, v in applyMSSQLOption(.dateCorrelationOptimization(v)) }
        }
    }

    @ViewBuilder
    private func mssqlFilesPage() -> some View {
        if mssqlFiles.isEmpty {
            Section {
                Text("No file information available.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(Array(mssqlFiles.enumerated()), id: \.offset) { _, file in
                Section(file.name) {
                    LabeledContent("Type", value: file.typeDescription)
                    if let fg = file.fileGroupName {
                        LabeledContent("Filegroup", value: fg)
                    }
                    LabeledContent("Size", value: String(format: "%.2f MB", file.sizeMB))
                    LabeledContent("Max Size", value: file.maxSizeDescription)
                    LabeledContent("Growth", value: file.growthDescription)
                    LabeledContent("Path", value: file.physicalName)
                }
            }
        }
    }

    // MARK: - PostgreSQL Pages

    @ViewBuilder
    private func postgresGeneralPage(_ props: PostgresDatabaseProperties) -> some View {
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
    private func postgresDefinitionPage(_ props: PostgresDatabaseProperties) -> some View {
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
    private func postgresParametersPage() -> some View {
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
    private func postgresStatisticsPage(_ props: PostgresDatabaseProperties) -> some View {
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

    // MARK: - MSSQL Apply Option

    private func applyMSSQLOption(_ option: SQLServerDatabaseOption) {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.makeAdministrationClient()
        isSaving = true
        statusMessage = nil

        Task {
            do {
                let messages = try await admin.alterDatabaseOption(name: databaseName, option: option)
                let info = messages.filter { $0.kind == .info }.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                isSaving = false
                if !info.isEmpty { statusMessage = info }
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            } catch {
                isSaving = false
                statusMessage = error.localizedDescription
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: error.localizedDescription, style: .error)
            }
        }
    }

    // MARK: - PostgreSQL Apply Alter

    private func applyPgAlter(_ action: @Sendable @escaping (PostgresAdmin) async throws -> Void) {
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

    // MARK: - Data Loading

    private func loadProperties() async {
        do {
            switch session.connection.databaseType {
            case .postgresql:
                try await loadPostgresProperties()
            case .microsoftSQL:
                try await loadMSSQLProperties()
            default:
                break
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadPostgresProperties() async throws {
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

        // Load parameters
        pgParams = (try? await admin.fetchDatabaseParameters(databaseOid: props.oid, using: pgSession.client)) ?? []

        // Load roles for owner picker
        let roles = try await metadata.listRoles(using: pgSession.client)
        pgRoles = roles.map(\.name).sorted()

        // Load tablespaces
        pgTablespaces = (try? await admin.listTablespaces(using: pgSession.client)) ?? ["pg_default"]
    }

    private func loadMSSQLProperties() async throws {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.makeAdministrationClient()
        let props = try await admin.fetchDatabaseProperties(name: databaseName)
        mssqlProps = props

        // Populate editable state
        recoveryModel = SQLServerDatabaseOption.RecoveryModel(rawValue: props.recoveryModel) ?? .full
        compatibilityLevel = props.compatibilityLevel
        isReadOnly = props.isReadOnly
        userAccess = SQLServerDatabaseOption.UserAccessOption.fromDescription(props.userAccessDescription)
        pageVerify = SQLServerDatabaseOption.PageVerifyOption(rawValue: props.pageVerifyOption) ?? .checksum
        targetRecoveryTime = props.targetRecoveryTimeSeconds
        delayedDurability = SQLServerDatabaseOption.DelayedDurabilityOption(rawValue: props.delayedDurability) ?? .disabled
        allowSnapshotIsolation = props.snapshotIsolationState.uppercased().contains("ON")
        readCommittedSnapshot = props.isReadCommittedSnapshotOn
        isEncrypted = props.isEncrypted
        isBrokerEnabled = props.isBrokerEnabled
        isTrustworthy = props.isTrustworthy
        parameterization = props.isParameterizationForced ? .forced : .simple
        autoClose = props.isAutoCloseOn
        autoShrink = props.isAutoShrinkOn
        autoCreateStats = props.isAutoCreateStatsOn
        autoUpdateStats = props.isAutoUpdateStatsOn
        autoUpdateStatsAsync = props.isAutoUpdateStatsAsyncOn
        ansiNullDefault = props.isAnsiNullDefaultOn
        ansiNulls = props.isAnsiNullsOn
        ansiPadding = props.isAnsiPaddingOn
        ansiWarnings = props.isAnsiWarningsOn
        arithAbort = props.isArithAbortOn
        concatNullYieldsNull = props.isConcatNullYieldsNullOn
        quotedIdentifier = props.isQuotedIdentifierOn
        recursiveTriggers = props.isRecursiveTriggersOn
        numericRoundAbort = props.isNumericRoundAbortOn
        dateCorrelation = props.isDateCorrelationOn

        // Load files
        mssqlFiles = (try? await admin.fetchDatabaseFiles(name: databaseName)) ?? []
    }

    // MARK: - Constants

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

// MARK: - Properties Page Enum

enum PropertiesPage: String, Hashable, CaseIterable {
    // Shared
    case general
    // MSSQL
    case options
    case automatic
    case ansi
    case files
    // PostgreSQL
    case definition
    case parameters
    case statistics

    var title: String {
        switch self {
        case .general: "General"
        case .options: "Options"
        case .automatic: "Automatic"
        case .ansi: "ANSI"
        case .files: "Files"
        case .definition: "Definition"
        case .parameters: "Parameters"
        case .statistics: "Statistics"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .options: "gearshape"
        case .automatic: "arrow.triangle.2.circlepath"
        case .ansi: "textformat"
        case .files: "doc"
        case .definition: "text.book.closed"
        case .parameters: "slider.horizontal.3"
        case .statistics: "chart.bar"
        }
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
