import SwiftUI

/// Top-level settings page for all database configuration.
/// Uses a grouped tab view (Calendar-style) to switch between database profiles.
struct DatabasesSettingsView: View {
    @Environment(ProjectStore.self) var projectStore

    @State private var selectedTab: DatabaseSettingsTab = .shared

    enum DatabaseSettingsTab: Hashable, CaseIterable {
        case shared
        case postgres
        case sqlserver
        case mysql
        case sqlite

        var title: String {
            switch self {
            case .shared: return "Shared"
            case .postgres: return "PostgreSQL"
            case .sqlserver: return "SQL Server"
            case .mysql: return "MySQL"
            case .sqlite: return "SQLite"
            }
        }
    }

    var settings: GlobalSettings {
        projectStore.globalSettings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .shared) {
                Form { sharedSettings }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
            } label: {
                Text("Shared")
            }

            Tab(value: .postgres) {
                Form { postgresSettings }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
            } label: {
                Text("PostgreSQL")
            }

            Tab(value: .sqlserver) {
                Form { sqlServerSettings }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
            } label: {
                Text("SQL Server")
            }

            Tab(value: .mysql) {
                Form { mySQLSettings }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
            } label: {
                Text("MySQL")
            }

            Tab(value: .sqlite) {
                Form { sqliteSettings }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
            } label: {
                Text("SQLite")
            }
        }
        .tabViewStyle(.grouped)
    }

    // MARK: - Simple Database Tabs

    @ViewBuilder
    var sqlServerSettings: some View {
        Section {
            DatabaseStreamingModeRow(selection: mssqlModeBinding)
        } header: {
            Text("Execution Profile")
        } footer: {
            Text("SQL Server currently supports a managed execution profile only.")
        }
    }

    @ViewBuilder
    var mySQLSettings: some View {
        Section("Execution Profile") {
            Text("MySQL streams results directly without explicit cursors or profile controls.")
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var sqliteSettings: some View {
        Section("Execution Profile") {
            Text("SQLite runs in-process, so network streaming and cursor profile controls do not apply.")
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
    }
}
