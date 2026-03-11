import SwiftUI

/// Top-level settings page for all database engine configuration.
/// Uses a segmented tab to switch between Shared defaults and per-engine profiles.
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
        Form {
            Section("Engine Scope") {
                Picker("", selection: $selectedTab) {
                    ForEach(DatabaseSettingsTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            switch selectedTab {
            case .shared:
                sharedSettings
            case .postgres:
                postgresSettings
            case .sqlserver:
                sqlServerSettings
            case .mysql:
                mySQLSettings
            case .sqlite:
                sqliteSettings
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Simple Engine Tabs

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
            Text("MySQL streams results directly without explicit cursors or engine profile controls.")
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
