import SwiftUI

/// Database-specific query editor toolbar controls — shown only when the active query tab
/// is connected to a database type that has specialized toggles.
/// Separate Liquid Glass group, positioned to the left of the generic query controls.
struct QueryEditorDatabaseToolbarControls: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, let query = tab.query {
            switch tab.connection.databaseType {
            case .microsoftSQL:
                MSSQLQueryToolbarControls(query: query)
            default:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - MSSQL Controls

private struct MSSQLQueryToolbarControls: View {
    @Bindable var query: QueryEditorState

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            sqlcmdModeButton
            statisticsButton
        }
        .glassEffect(.regular.interactive())
    }

    private var sqlcmdModeButton: some View {
        Button {
            query.sqlcmdModeEnabled.toggle()
        } label: {
            Label("SQLCMD", systemImage: "terminal")
                .symbolVariant(query.sqlcmdModeEnabled ? .fill : .none)
        }
        .labelStyle(.iconOnly)
        .help(query.sqlcmdModeEnabled ? "Disable SQLCMD Mode" : "Enable SQLCMD Mode")
        .accessibilityLabel(query.sqlcmdModeEnabled ? "Disable SQLCMD Mode" : "Enable SQLCMD Mode")
    }

    private var statisticsButton: some View {
        Button {
            query.statisticsEnabled.toggle()
        } label: {
            Label {
                Text("Statistics")
            } icon: {
                Image(systemName: query.statisticsEnabled ? "chart.bar.fill" : "chart.bar")
                    .frame(width: 16, height: 16)
                    .contentTransition(.identity)
            }
        }
        .labelStyle(.iconOnly)
        .help(query.statisticsEnabled ? "Disable Statistics IO/TIME" : "Enable Statistics IO/TIME")
        .accessibilityLabel(query.statisticsEnabled ? "Disable Statistics IO/TIME" : "Enable Statistics IO/TIME")
    }
}
