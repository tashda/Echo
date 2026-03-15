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

    @State var selectedPage: PropertiesPage = .general
    @State var isLoading = true
    @State var errorMessage: String?
    @State var isSaving = false
    @State var statusMessage: String?

    // MSSQL state
    @State var mssqlProps: SQLServerDatabaseProperties?
    @State var mssqlFiles: [SQLServerDatabaseFile] = []
    @State var recoveryModel: SQLServerDatabaseOption.RecoveryModel = .full
    @State var compatibilityLevel: Int = 160
    @State var isReadOnly = false
    @State var userAccess: SQLServerDatabaseOption.UserAccessOption = .multiUser
    @State var pageVerify: SQLServerDatabaseOption.PageVerifyOption = .checksum
    @State var targetRecoveryTime: Int = 0
    @State var delayedDurability: SQLServerDatabaseOption.DelayedDurabilityOption = .disabled
    @State var allowSnapshotIsolation = false
    @State var readCommittedSnapshot = false
    @State var isEncrypted = false
    @State var isBrokerEnabled = false
    @State var isTrustworthy = false
    @State var parameterization: SQLServerDatabaseOption.ParameterizationOption = .simple
    @State var autoClose = false
    @State var autoShrink = false
    @State var autoCreateStats = true
    @State var autoUpdateStats = true
    @State var autoUpdateStatsAsync = false
    @State var ansiNullDefault = false
    @State var ansiNulls = false
    @State var ansiPadding = false
    @State var ansiWarnings = false
    @State var arithAbort = false
    @State var concatNullYieldsNull = false
    @State var quotedIdentifier = false
    @State var recursiveTriggers = false
    @State var numericRoundAbort = false
    @State var dateCorrelation = false

    // MSSQL file editing state
    @State var fileSizeMBValues: [Int: Int] = [:]
    @State var fileMaxSizeTypes: [Int: FileMaxSizeType] = [:]
    @State var fileMaxSizeMBValues: [Int: Int] = [:]
    @State var fileGrowthTypes: [Int: FileGrowthType] = [:]
    @State var fileGrowthValues: [Int: Int] = [:]

    // PostgreSQL state
    @State var pgProps: PostgresDatabaseProperties?
    @State var pgParams: [PostgresDatabaseParameter] = []
    @State var pgRoles: [String] = []
    @State var pgTablespaces: [String] = []
    @State var pgOwner: String = ""
    @State var pgConnectionLimit: Int = -1
    @State var pgIsTemplate = false
    @State var pgAllowConnections = true
    @State var pgComment: String = ""

    var isMSSQL: Bool { session.connection.databaseType == .microsoftSQL }
    var isPostgres: Bool { session.connection.databaseType == .postgresql }

    var pages: [PropertiesPage] {
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
                sidebar
                    .frame(width: 170)

                Divider()

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack {
                if let status = statusMessage {
                    Text(status)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 640, minHeight: 480)
        .frame(idealWidth: 680, idealHeight: 520)
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
                    .foregroundStyle(ColorTokens.Text.secondary)
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

}
