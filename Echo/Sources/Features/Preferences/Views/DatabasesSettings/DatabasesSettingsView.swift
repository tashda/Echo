import SwiftUI

/// Top-level settings page for all database configuration.
/// Uses a grouped tab view (Calendar-style) to switch between database profiles.
struct DatabasesSettingsView: View {
    @Environment(ProjectStore.self) var projectStore

    @Binding var selectedTab: DatabaseSettingsTab

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
        VStack(spacing: 0) {
            Picker("Database", selection: $selectedTab) {
                ForEach(DatabaseSettingsTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, SpacingTokens.sm)
            .padding(.bottom, SpacingTokens.xs)

            switch selectedTab {
            case .mysql:
                mySQLSettings
            case .sqlite:
                sqliteSettings
            default:
                Form {
                    switch selectedTab {
                    case .shared:
                        sharedSettings
                    case .postgres:
                        postgresSettings
                    case .sqlserver:
                        sqlServerSettings
                    default:
                        EmptyView()
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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

        Section("Activity Monitor") {
            Picker("Refresh Interval", selection: activityMonitorIntervalBinding) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
            }
        }

        Section {
            Toggle("Hide inaccessible databases", isOn: hideInaccessibleDatabasesBinding)
        } header: {
            Text("Explorer Sidebar")
        } footer: {
            Text("When enabled, databases that the current login cannot access are hidden from the sidebar.")
        }
    }

    @ViewBuilder
    var mySQLSettings: some View {
        ContentUnavailableView {
            Label("No Settings", systemImage: "slider.horizontal.3")
        } description: {
            Text("There are no MySQL-specific settings at this time.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var sqliteSettings: some View {
        ContentUnavailableView {
            Label("No Settings", systemImage: "slider.horizontal.3")
        } description: {
            Text("There are no SQLite-specific settings at this time.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
