import SwiftUI
import SQLServerKit

extension MSSQLActivityMonitorView {
    @ViewBuilder
    internal var sectionTable: some View {
        if let snapshot = viewModel.latestSnapshot, case .mssql(let snap) = snapshot {
            switch selectedSection {
            case .processes:
                if snap.processes.isEmpty {
                    activityEmptyState("No Active Sessions", systemImage: "person.2.slash", description: "No user sessions are currently active on this server.")
                } else {
                    MSSQLActivityProcesses(
                        processes: snap.processes,
                        sortOrder: $processesSortOrder,
                        selection: $selectedProcessIDs,
                        onPopout: { sql in popout(sql) },
                        onKill: kill,
                        canKill: environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)?.permissions?.canManageServerState ?? true,
                        onDoubleClick: { appState.showInfoSidebar.toggle() }
                    )
                }
            case .waits:
                if snap.waitsDelta == nil {
                    ActivitySectionLoadingView(title: "Collecting Wait Statistics", subtitle: "Waiting for baseline data\u{2026}")
                } else if snap.waitsDelta?.isEmpty == true {
                    activityEmptyState("No Wait Activity", systemImage: "hourglass", description: "No meaningful SQL Server waits were recorded in the latest interval.")
                } else {
                    MSSQLActivityWaits(
                        waits: snap.waitsDelta ?? [],
                        sortOrder: $waitsSortOrder,
                        selection: $selectedWaitIDs,
                        onDoubleClick: { appState.showInfoSidebar.toggle() }
                    )
                }
            case .io:
                if snap.fileIODelta == nil {
                    ActivitySectionLoadingView(title: "Collecting I/O Statistics", subtitle: "Waiting for baseline data\u{2026}")
                } else if snap.fileIODelta?.isEmpty == true {
                    activityEmptyState("No I/O Activity", systemImage: "externaldrive", description: "No database file I/O was recorded in the latest interval.")
                } else {
                    MSSQLActivityFileIO(
                        io: snap.fileIODelta ?? [],
                        sortOrder: $ioSortOrder,
                        selection: $selectedIOIDs,
                        onDoubleClick: { appState.showInfoSidebar.toggle() }
                    )
                }
            case .queries:
                if snap.expensiveQueries.isEmpty {
                    activityEmptyState("No Expensive Queries", systemImage: "text.magnifyingglass", description: "No expensive queries were recorded in the latest snapshot.")
                } else {
                    MSSQLActivityQueries(
                        queries: snap.expensiveQueries,
                        sortOrder: $queriesSortOrder,
                        selection: $selectedQueryIDs,
                        onPopout: { sql in popout(sql) },
                        onOpenInQueryWindow: { sql, db in environmentState.openFormattedQueryTab(sql: sql, database: db, connectionID: viewModel.connectionID, dialect: .microsoftSQL) },
                        onDoubleClick: { appState.showInfoSidebar.toggle() }
                    )
                }
            case .xevents, .profiler:
                EmptyView()
            }
        } else {
            EmptyTablePlaceholder()
        }
    }

    private func activityEmptyState(
        _ title: LocalizedStringKey,
        systemImage: String,
        description: LocalizedStringKey
    ) -> some View {
        TabContentUnavailableView(title, systemImage: systemImage) {
            Text(description)
        }
    }

    @ViewBuilder
    internal var xeventsContent: some View {
        if let xeVM = viewModel.extendedEventsVM {
            ExtendedEventsView(
                viewModel: xeVM,
                panelState: xeventsPanelState,
                onPopout: { sql in popout(sql) },
                onDoubleClick: { appState.showInfoSidebar.toggle() }
            )
        } else {
            ContentUnavailableView {
                Label("Extended Events", systemImage: "waveform.path.ecg")
            } description: {
                Text("Extended Events is not available for this connection.")
            }
        }
    }

    @ViewBuilder
    internal var profilerContent: some View {
        if let profilerVM = viewModel.profilerVM {
            ProfilerView(
                viewModel: profilerVM,
                onPopout: { sql in popout(sql) },
                onDoubleClick: { appState.showInfoSidebar.toggle() }
            )
        } else {
            ContentUnavailableView {
                Label("SQL Profiler", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("SQL Profiler is not available for this connection.")
            }
        }
    }
}
