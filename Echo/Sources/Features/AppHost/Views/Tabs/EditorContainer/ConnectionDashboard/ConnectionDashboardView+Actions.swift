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
        HStack(spacing: SpacingTokens.xs) {
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
    }

    // MARK: - PostgreSQL

    @ViewBuilder
    private var postgresTools: some View {
        DashboardToolCard(icon: "gauge.with.dots.needle.33percent", label: "Activity Monitor") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }

        DashboardToolCard(icon: "wrench.and.screwdriver", label: "Maintenance", menuItems: databases.map(\.name)) { db in
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: db)
        } directAction: {
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: defaultDatabase)
        }

        DashboardToolCard(icon: "terminal", label: "Console", menuItems: databases.map(\.name)) { db in
            environmentState.openPSQLTab(for: session, database: db)
        } directAction: {
            environmentState.openPSQLTab(for: session)
        }

        DashboardToolCard(icon: "apple.terminal", label: "psql", menuItems: databases.map(\.name)) { db in
            environmentState.openInPsql(for: session, database: db)
        } directAction: {
            environmentState.openInPsql(for: session)
        }
    }

    // MARK: - MySQL

    @ViewBuilder
    private var mysqlTools: some View {
        DashboardToolCard(icon: "gauge.with.dots.needle.33percent", label: "Activity Monitor") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }

        DashboardToolCard(icon: "wrench.and.screwdriver", label: "Maintenance", menuItems: databases.map(\.name)) { db in
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: db)
        } directAction: {
            environmentState.openMaintenanceTab(connectionID: session.connection.id, databaseName: defaultDatabase)
        }
    }

    // MARK: - SQLite

    @ViewBuilder
    private var sqliteTools: some View {
        DashboardToolCard(icon: "wrench.and.screwdriver", label: "Maintenance") {
            environmentState.openMaintenanceTab(connectionID: session.connection.id)
        }
    }

    // MARK: - MSSQL

    @ViewBuilder
    private var mssqlTools: some View {
        DashboardToolCard(icon: "gauge.with.dots.needle.33percent", label: "Activity Monitor") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }

        DashboardToolCard(icon: "clock.badge.checkmark", label: "Agent Jobs") {
            environmentState.openJobQueueTab(for: session)
        }

        DashboardToolCard(icon: "chart.bar.xaxis", label: "Query Store", menuItems: databases.map(\.name)) { db in
            environmentState.openQueryStoreTab(connectionID: session.connection.id, databaseName: db)
        } directAction: {
            environmentState.openQueryStoreTab(connectionID: session.connection.id, databaseName: defaultDatabase)
        }

        DashboardToolCard(icon: "waveform.path.ecg", label: "Events") {
            environmentState.openExtendedEventsTab(connectionID: session.connection.id)
        }
    }
}

// MARK: - Tool Card

/// A dashboard tool card rendered as a plain Button.
/// When `menuItems` has more than one entry, clicking shows an NSMenu.
/// Otherwise clicks trigger `directAction` immediately.
private struct DashboardToolCard: View {
    let icon: String
    let label: String
    var menuItems: [String] = []
    var menuAction: ((String) -> Void)?
    let directAction: () -> Void

    @State private var isHovered = false

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

    private var needsMenu: Bool {
        menuItems.count > 1 && menuAction != nil
    }

    var body: some View {
        Button {
            if needsMenu {
                showMenu()
            } else {
                directAction()
            }
        } label: {
            VStack(spacing: SpacingTokens.xxs) {
                Image(systemName: icon)
                    .font(TypographyTokens.prominent)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(height: 20)
                Text(label)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sm)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? ColorTokens.Surface.hover : ColorTokens.Surface.rest)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func showMenu() {
        guard let menuAction else { return }
        let coordinator = ToolCardMenuCoordinator(action: menuAction)
        let menu = NSMenu()
        for item in menuItems {
            let menuItem = NSMenuItem(title: item, action: #selector(ToolCardMenuCoordinator.itemSelected(_:)), keyEquivalent: "")
            menuItem.target = coordinator
            menu.addItem(menuItem)
        }
        // Prevent coordinator from being deallocated while menu is open
        objc_setAssociatedObject(menu, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)

        guard let event = NSApp.currentEvent,
              let window = event.window,
              let contentView = window.contentView else { return }

        let location = contentView.convert(event.locationInWindow, from: nil)
        _ = menu.popUp(positioning: nil, at: location, in: contentView)
    }
}

// MARK: - Menu Coordinator

private final class ToolCardMenuCoordinator: NSObject {
    let action: (String) -> Void

    init(action: @escaping (String) -> Void) {
        self.action = action
    }

    @objc func itemSelected(_ sender: NSMenuItem) {
        action(sender.title)
    }
}
