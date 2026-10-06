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
            TabSectionPicker(
                "Database Settings Section",
                selection: $selectedTab,
                itemCount: DatabaseSettingsTab.allCases.count
            ) {
                ForEach(DatabaseSettingsTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .padding(.top, SpacingTokens.sm)
            .padding(.bottom, SpacingTokens.xs)

            switch selectedTab {
            case .mysql:
                Form {
                    mySQLSettings
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
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
            Picker("Refresh Interval", selection: activityMonitorIntervalBinding) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
            }
            Toggle("Slow down when not shown", isOn: activityMonitorSlowsWhenHiddenBinding)
        } header: {
            Text("Activity Monitor")
        } footer: {
            Text("A monitor in a tab you are not looking at asks the server once a minute instead of at this rate, which spares the server and the network. Turn it off to keep the chosen rate.")
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
    var sqliteSettings: some View {
        ContentUnavailableView {
            Label("No Settings", systemImage: "slider.horizontal.3")
        } description: {
            Text("There are no SQLite-specific settings at this time.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
