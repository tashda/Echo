import SwiftUI
import PostgresKit
import SQLServerKit

/// Settings-style "New Database" dialog with sidebar categories and detail pane.
/// Matches the layout of ``DatabasePropertiesSheet``.
struct NewDatabaseSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State var selectedPage: NewDatabasePage = .general
    @State var isCreating = false
    @State var errorMessage: String?
    @State var isLoadingOptions = true

    // Shared
    @State var databaseName = ""
    @State var owner = ""

    // PostgreSQL
    @State var pgComment = ""
    @State var pgTemplate: String?
    @State var pgEncoding = "UTF8"
    @State var pgTablespace = "pg_default"
    @State var pgLocaleProvider = "libc"
    @State var pgCollation = ""
    @State var pgCtype = ""
    @State var pgIcuLocale = ""
    @State var pgIcuRules = ""
    @State var pgConnectionLimit = -1
    @State var pgIsTemplate = false
    @State var pgAllowConnections = true
    @State var pgStrategy = "wal_log"
    // Lookup lists
    @State var pgRoles: [String] = []
    @State var pgTemplates: [String] = []
    @State var pgEncodings: [String] = []
    @State var pgCollations: [String] = []
    @State var pgTablespaces: [String] = []

    // MSSQL
    @State var mssqlCollation = ""
    @State var mssqlCollations: [String] = []
    @State var mssqlContainment = "NONE"
    @State var mssqlDataFileName = ""
    @State var mssqlDataFileSize = 8
    @State var mssqlDataFileMaxSize = 0
    @State var mssqlDataFileGrowth = 64
    @State var mssqlLogFileName = ""
    @State var mssqlLogFileSize = 8
    @State var mssqlLogFileMaxSize = 0
    @State var mssqlLogFileGrowth = 64

    var isMSSQL: Bool { session.connection.databaseType == .microsoftSQL }
    var isPostgres: Bool { session.connection.databaseType == .postgresql }

    var pages: [NewDatabasePage] {
        if isMSSQL {
            return [.general, .files, .options, .sql]
        } else if isPostgres {
            return [.general, .definition, .sql]
        } else {
            return [.general]
        }
    }

    var canCreate: Bool {
        !databaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
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
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(1)
                }
                Spacer()
                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { createDatabase() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 640, minHeight: 480)
        .frame(idealWidth: 680, idealHeight: 520)
        .task { await loadOptions() }
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
        if isLoadingOptions {
            VStack {
                Spacer()
                ProgressView("Loading options\u{2026}")
                Spacer()
            }
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
            if isPostgres {
                postgresGeneralPage()
            } else if isMSSQL {
                mssqlGeneralPage()
            }
        case .definition:
            if isPostgres {
                postgresDefinitionPage()
            }
        case .files:
            if isMSSQL {
                mssqlFilesPage()
            }
        case .options:
            if isMSSQL {
                mssqlOptionsPage()
            }
        case .sql:
            sqlPage()
        }
    }
}

// MARK: - Page Enum

enum NewDatabasePage: String, Hashable, CaseIterable {
    case general
    case definition
    case files
    case options
    case sql

    var title: String {
        switch self {
        case .general: "General"
        case .definition: "Definition"
        case .files: "Files"
        case .options: "Options"
        case .sql: "SQL"
        }
    }

    var icon: String {
        switch self {
        case .general: "info.circle"
        case .definition: "text.book.closed"
        case .files: "doc"
        case .options: "gearshape"
        case .sql: "chevron.left.forwardslash.chevron.right"
        }
    }
}
