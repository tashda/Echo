import SwiftUI

struct ConnectionDashboardTools: View {
    @Bindable var session: ConnectionSession
    @Environment(EnvironmentState.self) private var environmentState

    private var databases: [DatabaseInfo] {
        session.databaseStructure?.databases ?? []
    }

    private var defaultDatabase: String {
        session.sidebarFocusedDatabase ?? session.connection.database
    }

    var body: some View {
        // One row when it fits; otherwise the buttons wrap.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SpacingTokens.xs) { buttons }
            FlowLayout(spacing: SpacingTokens.xs) { buttons }
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            environmentState.openQueryTab(for: session, database: defaultDatabase.isEmpty ? nil : defaultDatabase)
        } label: {
            Label("New Query", systemImage: "plus")
        }
        .buttonStyle(.glassProminent)

        switch session.connection.databaseType {
        case .postgresql:
            postgresTools
        case .microsoftSQL:
            mssqlTools
        case .mysql:
            mysqlTools
        case .sqlite:
            sqliteTools
        }
    }

    // MARK: - PostgreSQL

    @ViewBuilder
    private var postgresTools: some View {
        DashboardToolButton(icon: "gauge.with.dots.needle.33percent", label: "Activity Monitor") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }

        DashboardToolButton(icon: "wrench.and.screwdriver", label: "Maintenance", menuItems: databases.map(\.name)) { db in
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: db)
        } directAction: {
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: defaultDatabase)
        }

        DashboardToolButton(icon: "terminal", label: "Console", menuItems: databases.map(\.name)) { db in
            environmentState.openPSQLTab(for: session, database: db)
        } directAction: {
            environmentState.openPSQLTab(for: session)
        }

        DashboardToolButton(icon: "apple.terminal", label: "psql", menuItems: databases.map(\.name)) { db in
            environmentState.openInPsql(for: session, database: db)
        } directAction: {
            environmentState.openInPsql(for: session)
        }
    }

    // MARK: - MySQL

    @ViewBuilder
    private var mysqlTools: some View {
        DashboardToolButton(icon: "gauge.with.dots.needle.33percent", label: "Activity Monitor") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }

        DashboardToolButton(icon: "wrench.and.screwdriver", label: "Maintenance", menuItems: databases.map(\.name)) { db in
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: db)
        } directAction: {
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: defaultDatabase)
        }
    }

    // MARK: - SQLite

    @ViewBuilder
    private var sqliteTools: some View {
        DashboardToolButton(icon: "wrench.and.screwdriver", label: "Maintenance") {
            environmentState.openMaintenanceTab(connectionID: session.connection.id)
        }
    }

    // MARK: - MSSQL

    @ViewBuilder
    private var mssqlTools: some View {
        DashboardToolButton(icon: "gauge.with.dots.needle.33percent", label: "Activity Monitor") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }

        DashboardToolButton(icon: "clock.badge.checkmark", label: "Agent Jobs") {
            environmentState.openJobQueueTab(for: session)
        }

        DashboardToolButton(icon: "chart.bar.xaxis", label: "Query Store", menuItems: databases.map(\.name)) { db in
            environmentState.openQueryStoreTab(connectionID: session.connection.id, databaseName: db)
        } directAction: {
            environmentState.openQueryStoreTab(connectionID: session.connection.id, databaseName: defaultDatabase)
        }

        DashboardToolButton(icon: "waveform.path.ecg", label: "Events") {
            environmentState.openExtendedEventsTab(connectionID: session.connection.id)
        }
    }
}

// MARK: - Tool Button

/// A server tool on a Liquid Glass button. With several databases to choose from it opens a
/// menu of them; otherwise it acts straight away.
private struct DashboardToolButton: View {
    let icon: String
    let label: String
    var menuItems: [String] = []
    var menuAction: ((String) -> Void)?
    let directAction: () -> Void

    init(icon: String, label: String, directAction: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.directAction = directAction
    }

    init(icon: String, label: String, menuItems: [String], menuAction: @escaping (String) -> Void, directAction: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.menuItems = menuItems
        self.menuAction = menuAction
        self.directAction = directAction
    }

    var body: some View {
        if menuItems.count > 1, let menuAction {
            Menu {
                ForEach(menuItems, id: \.self) { item in
                    Button(item) { menuAction(item) }
                }
            } label: {
                Label(label, systemImage: icon)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.glass)
            .fixedSize()
        } else {
            Button(action: directAction) {
                Label(label, systemImage: icon)
            }
            .buttonStyle(.glass)
        }
    }
}
