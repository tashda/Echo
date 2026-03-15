import Foundation
import SwiftUI
import Charts
import SQLServerKit
import PostgresWire

struct ActivityMonitorView: View {
    @ObservedObject var viewModel: ActivityMonitorViewModel
    @EnvironmentObject private var environmentState: EnvironmentState
    
    // Sorting states
    @State private var processesSortOrder = [KeyPathComparator(\SQLServerProcessInfo.sessionId)]
    @State private var waitsSortOrder = [KeyPathComparator(\SQLServerWaitStatDelta.waitTimeMsDelta, order: .reverse)]
    @State private var ioSortOrder = [KeyPathComparator(\SQLServerFileIOStatDelta.ioStallReadMsDelta, order: .reverse)]
    @State private var queriesSortOrder = [KeyPathComparator(\SQLServerExpensiveQuery.totalWorkerTime, order: .reverse)]
    
    @State private var pgProcessesSortOrder = [KeyPathComparator(\PostgresProcessInfo.pid)]
    @State private var pgWaitsSortOrder = [KeyPathComparator(\PostgresWaitStatDelta.countDelta, order: .reverse)]
    @State private var pgIOSortOrder = [KeyPathComparator(\PostgresDatabaseStatDelta.xact_commit_delta, order: .reverse)]
    @State private var pgQueriesSortOrder = [KeyPathComparator(\PostgresExpensiveQuery.total_exec_time, order: .reverse)]

    // Pop-out state
    @State private var selectedSQLContext: SQLPopoutContext?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            if viewModel.latestSnapshot == nil {
                loadingView
            } else {
                contentView
            }
        }
        .background(ColorTokens.Background.primary)
        .sheet(item: $selectedSQLContext) { context in
            SQLInspectorPopover(context: context) { sql in
                openInQueryWindow(sql: sql)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
            Text("Initializing Activity Monitor...")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xl) {
                // 1. Dashboard Overview
                SectionContainer(title: "System Performance", icon: "chart.xyaxis.line") {
                    OverviewGraphsView(viewModel: viewModel)
                        .padding(.top, SpacingTokens.xs)
                }
                
                // 2. Active Processes
                SectionContainer(title: "Active Processes", icon: "person.2.fill", info: "Real-time view of user and system sessions. Right-click a row to Kill or see Details.") {
                    ProcessesTableView(viewModel: viewModel, sortOrder: processesSortBinding, pgSortOrder: pgProcessesSortBinding) { sql in
                        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Process Query")
                    }
                    .frame(minHeight: viewModel.latestSnapshot?.processes.isEmpty == false ? 350 : 120)
                }
                
                // 3. Resource & Wait Analysis
                HStack(alignment: .top, spacing: SpacingTokens.xl) {
                    SectionContainer(title: "Top Resource Waits", icon: "hourglass", info: "Cumulative time tasks spent waiting for specific resources.") {
                        ResourceWaitsTableView(viewModel: viewModel, sortOrder: waitsSortBinding, pgSortOrder: pgWaitsSortBinding)
                            .frame(minHeight: 200)
                    }
                    .frame(maxWidth: .infinity)
                    
                    SectionContainer(title: "Data File Activity", icon: "doc.text.fill", info: "Real-time I/O throughput and latency per database/file.") {
                        DataFileIOTableView(viewModel: viewModel, sortOrder: ioSortBinding, pgSortOrder: pgIOSortBinding)
                            .frame(minHeight: 200)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // 4. Expensive Queries
                SectionContainer(title: "Expensive Queries", icon: "bolt.horizontal.circle.fill", info: "The most resource-intensive queries recorded since server start.") {
                    ExpensiveQueriesTableView(
                        viewModel: viewModel, 
                        sortOrder: queriesSortBinding, 
                        pgSortOrder: pgQueriesSortBinding,
                        onOpenExtensionManager: { openExtensionManager() }
                    ) { sql in
                        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Expensive Query")
                    }
                    .frame(minHeight: viewModel.latestSnapshot?.expensiveQueries.isEmpty == false ? 300 : 120)
                }
            }
            .padding(SpacingTokens.lg)
        }
    }

    // MARK: - Sort Bindings
    
    private var processesSortBinding: Binding<[KeyPathComparator<SQLServerProcessInfo>]> {
        Binding(get: { processesSortOrder }, set: { processesSortOrder = $0 })
    }
    private var pgProcessesSortBinding: Binding<[KeyPathComparator<PostgresProcessInfo>]> {
        Binding(get: { pgProcessesSortOrder }, set: { pgProcessesSortOrder = $0 })
    }
    private var waitsSortBinding: Binding<[KeyPathComparator<SQLServerWaitStatDelta>]> {
        Binding(get: { waitsSortOrder }, set: { waitsSortOrder = $0 })
    }
    private var pgWaitsSortBinding: Binding<[KeyPathComparator<PostgresWaitStatDelta>]> {
        Binding(get: { pgWaitsSortOrder }, set: { pgWaitsSortOrder = $0 })
    }
    private var ioSortBinding: Binding<[KeyPathComparator<SQLServerFileIOStatDelta>]> {
        Binding(get: { ioSortOrder }, set: { ioSortOrder = $0 })
    }
    private var pgIOSortBinding: Binding<[KeyPathComparator<PostgresDatabaseStatDelta>]> {
        Binding(get: { pgIOSortOrder }, set: { pgIOSortOrder = $0 })
    }
    private var queriesSortBinding: Binding<[KeyPathComparator<SQLServerExpensiveQuery>]> {
        Binding(get: { queriesSortOrder }, set: { queriesSortOrder = $0 })
    }
    private var pgQueriesSortBinding: Binding<[KeyPathComparator<PostgresExpensiveQuery>]> {
        Binding(get: { pgQueriesSortOrder }, set: { pgQueriesSortOrder = $0 })
    }

    private func openInQueryWindow(sql: String) {
        if let sessionID = viewModel.latestSnapshotSessionID,
           let session = environmentState.sessionCoordinator.activeSessions.first(where: { $0.id == sessionID }) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        } else {
            environmentState.openQueryTab(presetQuery: sql)
        }
    }

    private func openExtensionManager() {
        guard let sessionID = viewModel.latestSnapshotSessionID,
              let session = environmentState.sessionCoordinator.activeSessions.first(where: { $0.id == sessionID }) else { return }
        
        let database = session.selectedDatabaseName ?? session.connection.database
        session.addExtensionsManagerTab(databaseName: database) 
    }
    
    private var toolbar: some View {
        HStack {
            HStack(spacing: SpacingTokens.sm) {
                Button(action: {
                    if viewModel.isRunning {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.startStreaming()
                    }
                }) {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .padding(SpacingTokens.xxs2)
                .background(ColorTokens.Background.tertiary)
                .cornerRadius(6)
                .help(viewModel.isRunning ? "Pause Monitoring" : "Resume Monitoring")
                
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .padding(SpacingTokens.xxs2)
                .background(ColorTokens.Background.tertiary)
                .cornerRadius(6)
                .help("Force Refresh")
            }
            
            Divider().frame(height: 16).padding(.horizontal, SpacingTokens.xs)
            
            HStack(spacing: SpacingTokens.xs) {
                Text("Refresh Every:")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                
                Picker("", selection: $viewModel.refreshInterval) {
                    Text("1s").tag(TimeInterval(1.0))
                    Text("2s").tag(TimeInterval(2.0))
                    Text("5s").tag(TimeInterval(5.0))
                    Text("10s").tag(TimeInterval(10.0))
                }
                .pickerStyle(.menu)
                .frame(width: 70)
                .labelsHidden()
                .onChange(of: viewModel.refreshInterval) { _, _ in
                    if viewModel.isRunning { viewModel.startStreaming() }
                }
            }
            
            Spacer()
            
            if let last = viewModel.latestSnapshot {
                HStack(spacing: SpacingTokens.xxs) {
                    Circle()
                        .fill(viewModel.isRunning ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                        .frame(width: 6, height: 6)
                    Text("Last update: \(last.capturedAt, style: .time)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
        .overlay(Divider(), alignment: .bottom)
    }
}

// MARK: - Components

struct SQLPopoutContext: Identifiable {
    let id = UUID()
    let sql: String
    let title: String
}

struct SQLInspectorPopover: View {
    let context: SQLPopoutContext
    let onOpenInWindow: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(context.title)
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()
                
                HStack(spacing: SpacingTokens.sm) {
                    Button("Copy SQL") {
                        PlatformClipboard.copy(context.sql)
                    }
                    
                    Button("Open in Query Window") {
                        onOpenInWindow(context.sql)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)
            
            Divider()
            
            ScrollView {
                Text(context.sql)
                    .font(TypographyTokens.monospaced)
                    .padding(SpacingTokens.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(ColorTokens.Background.secondary.opacity(0.5))
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct SQLQueryCell: View {
    let sql: String
    let onPopout: (String) -> Void
    
    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(sql.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(TypographyTokens.monospaced)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            Button(action: { onPopout(sql) }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Expand SQL")
        }
        .contextMenu {
            Button("Expand SQL") { onPopout(sql) }
            Button("Copy SQL") { PlatformClipboard.copy(sql) }
        }
    }
}

struct SectionInfoButton: View {
    let info: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            Text(info)
                .font(TypographyTokens.detail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.sm)
                .frame(width: 250)
        }
    }
}

/// A modern container for dashboard sections
struct SectionContainer<Content: View>: View {
    let title: String
    let icon: String
    let info: String?
    let content: () -> Content
    
    init(title: String, icon: String, info: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.info = info
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: icon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.accent)
                Text(title.uppercased())
                    .font(TypographyTokens.detail.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .kerning(0.5)
                
                if let info = info {
                   SectionInfoButton(info: info)
                }
                }
                .padding(.leading, SpacingTokens.xxxs)
            content()
                .background(ColorTokens.Background.secondary.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTokens.Text.primary.opacity(0.05), lineWidth: 1)
                )
        }
    }
}

struct OverviewGraphsView: View {
    @ObservedObject var viewModel: ActivityMonitorViewModel
    
    var body: some View {
        Grid(horizontalSpacing: SpacingTokens.lg, verticalSpacing: SpacingTokens.lg) {
            GridRow {
                GraphCell(
                    title: "% Processor Time",
                    data: viewModel.cpuHistory,
                    unit: "%",
                    maxValue: 100,
                    color: .blue,
                    info: "Estimated CPU utilization based on active (non-idle) database sessions relative to server capacity."
                )
                GraphCell(
                    title: "Waiting Tasks",
                    data: viewModel.waitingTasksHistory,
                    unit: "",
                    maxValue: nil,
                    color: .orange,
                    info: "The number of tasks currently blocked waiting for a resource (lock, memory, disk, etc)."
                )
            }
            GridRow {
                GraphCell(
                    title: "Database I/O",
                    data: viewModel.ioHistory,
                    unit: " MB/s",
                    maxValue: nil,
                    color: .purple,
                    info: "Current volume of data being read from or written to the data files per second."
                )
                GraphCell(
                    title: "Throughput",
                    data: viewModel.throughputHistory,
                    unit: " /s",
                    maxValue: nil,
                    color: .green,
                    info: "Rate of work being completed (Batch Requests/sec for MSSQL, Transactions/sec for Postgres)."
                )
            }
        }
        .padding(SpacingTokens.md)
    }
}

struct GraphCell: View {
    let title: String
    let data: [ActivityMonitorViewModel.GraphPoint]
    let unit: String
    let maxValue: Double?
    let color: Color
    let info: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text(title)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)
                
                SectionInfoButton(info: info)
                
                Spacer()
                if let last = data.last?.value {
                    Text("\(Int(last))\(unit)")
                        .font(TypographyTokens.standard.weight(.bold))
                        .foregroundStyle(color)
                }
            }
            
            Chart(data) {
                AreaMark(
                    x: .value("Time", $0.timestamp),
                    y: .value("Value", $0.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .interpolationMethod(.monotone)
                
                LineMark(
                    x: .value("Time", $0.timestamp),
                    y: .value("Value", $0.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(dash: [2, 4]))
                        .foregroundStyle(ColorTokens.Text.primary.opacity(0.1))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue))")
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...(maxValue ?? max(10, data.map { $0.value }.max() ?? 0) * 1.2))
            .frame(height: 80)
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Text.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

struct StatusBadge: View {
    let text: String
    let isSystem: Bool
    
    init(text: String, isSystem: Bool = false) {
        self.text = text.isEmpty ? (isSystem ? "System" : "Unknown") : text
        self.isSystem = isSystem
    }
    
    var body: some View {
        Text(text)
            .font(TypographyTokens.compact.weight(.bold))
            .padding(.horizontal, SpacingTokens.xxs2)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        if isSystem { return ColorTokens.Status.info }
        switch text.lowercased() {
        case "active", "running", "runnable": return ColorTokens.Status.success
        case "sleeping", "idle": return ColorTokens.Text.secondary
        case "suspended", "blocked": return ColorTokens.Status.error
        default: return ColorTokens.Text.secondary
        }
    }
}

// MARK: - Tables

struct ProcessesTableView: View {
    @ObservedObject var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerProcessInfo>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresProcessInfo>]
    let onPopout: (String) -> Void
    
    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLProcessesTable(processes: snap.processes, sortOrder: $sortOrder, onPopout: onPopout, onKill: { id in
                    Task { try? await viewModel.killSession(id: id) }
                })
            case .postgres(let snap):
                PostgresProcessesTable(processes: snap.processes, sortOrder: $pgSortOrder, onPopout: onPopout, onKill: { id in
                    Task { try? await viewModel.killSession(id: id) }
                })
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct ResourceWaitsTableView: View {
    @ObservedObject var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerWaitStatDelta>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresWaitStatDelta>]
    
    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLWaitsTable(waits: snap.waitsDelta ?? [], sortOrder: $sortOrder)
            case .postgres(let snap):
                PostgresWaitsTable(waits: snap.waitsDelta ?? [], sortOrder: $pgSortOrder)
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct DataFileIOTableView: View {
    @ObservedObject var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerFileIOStatDelta>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresDatabaseStatDelta>]
    
    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLFileIOTable(io: snap.fileIODelta ?? [], sortOrder: $sortOrder)
            case .postgres(let snap):
                PostgresDBStatsTable(stats: snap.databaseStatsDelta ?? [], sortOrder: $pgSortOrder)
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct ExpensiveQueriesTableView: View {
    @ObservedObject var viewModel: ActivityMonitorViewModel
    @Binding var sortOrder: [KeyPathComparator<SQLServerExpensiveQuery>]
    @Binding var pgSortOrder: [KeyPathComparator<PostgresExpensiveQuery>]
    let onOpenExtensionManager: () -> Void
    let onPopout: (String) -> Void
    
    @State private var showEnablePopover = false
    
    var body: some View {
        if let snapshot = viewModel.latestSnapshot {
            switch snapshot {
            case .mssql(let snap):
                MSSQLExpensiveQueriesTable(queries: snap.expensiveQueries, sortOrder: $sortOrder, onPopout: onPopout)
            case .postgres(let snap):
                if snap.pgStatStatementsAvailable {
                    PostgresExpensiveQueriesTable(queries: snap.expensiveQueries, sortOrder: $pgSortOrder, onPopout: onPopout)
                } else {
                    VStack(spacing: SpacingTokens.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(TypographyTokens.hero)
                            .foregroundStyle(ColorTokens.Status.warning)
                        Text("pg_stat_statements Not Found")
                            .font(TypographyTokens.headline)
                        Text("This extension is required to track expensive queries in PostgreSQL.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("How to enable?") {
                            showEnablePopover = true
                        }
                        .buttonStyle(.link)
                        .popover(isPresented: $showEnablePopover) {
                            PGStatStatementsGuide(onOpenManager: {
                                showEnablePopover = false
                                onOpenExtensionManager()
                            })
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(SpacingTokens.lg)
                }
            }
        } else {
            EmptyTablePlaceholder()
        }
    }
}

struct PGStatStatementsGuide: View {
    let onOpenManager: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .foregroundStyle(ColorTokens.Status.info)
                Text("Enable Expensive Query Tracking")
                    .font(TypographyTokens.headline)
            }
            
            Text("PostgreSQL requires the `pg_stat_statements` extension to track detailed query performance metrics.")
                .font(TypographyTokens.detail)
            
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                Label("Add to `shared_preload_libraries` in `postgresql.conf`", systemImage: "1.circle")
                Label("Restart the PostgreSQL server", systemImage: "2.circle")
                Label("Run `CREATE EXTENSION pg_stat_statements;`", systemImage: "3.circle")
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            
            Button("Open Extension Manager") {
                onOpenManager()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, SpacingTokens.xxs)
        }
        .padding(SpacingTokens.lg)
        .frame(width: 380)
    }
}

struct EmptyTablePlaceholder: View {
    var body: some View {
        VStack {
            Text("No activity data available")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - MSSQL Tables

struct MSSQLProcessesTable: View {
    let processes: [SQLServerProcessInfo]
    @Binding var sortOrder: [KeyPathComparator<SQLServerProcessInfo>]
    let onPopout: (String) -> Void
    let onKill: (Int) -> Void
    
    private var sortedProcesses: [SQLServerProcessInfo] {
        processes.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedProcesses, sortOrder: $sortOrder) {
            TableColumn("ID", value: \.sessionId) { Text("\($0.sessionId)") }.width(min: 40, max: 60)
            TableColumn("User") { 
                Text($0.loginName ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(($0.loginName ?? "").isEmpty ? ColorTokens.Text.secondary : ColorTokens.Text.primary)
            }.width(min: 100)
            TableColumn("Status") { StatusBadge(text: $0.sessionStatus ?? "", isSystem: ($0.loginName ?? "").isEmpty) }.width(80)
            TableColumn("Command") { 
                if let sql = $0.request?.sqlText, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                } else {
                    Text($0.request?.command ?? "")
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            TableColumn("CPU", value: \.sessionCpuTimeMs!) { Text("\($0.sessionCpuTimeMs ?? 0)ms").font(TypographyTokens.detail) }.width(70)
            TableColumn("Memory", value: \.memoryUsageKB!) { Text("\($0.memoryUsageKB ?? 0) KB").font(TypographyTokens.detail) }.width(80)
        }
        .contextMenu(forSelectionType: SQLServerProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button("Details") {
                    if let sql = process.request?.sqlText { onPopout(sql) }
                }
                .disabled(process.request?.sqlText == nil)
                
                Divider()
                
                Button("Kill Process", role: .destructive) {
                    onKill(id)
                }
            }
        }
    }
}

struct MSSQLWaitsTable: View {
    let waits: [SQLServerWaitStatDelta]
    @Binding var sortOrder: [KeyPathComparator<SQLServerWaitStatDelta>]
    
    private var sortedWaits: [SQLServerWaitStatDelta] {
        waits.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedWaits, sortOrder: $sortOrder) {
            TableColumn("Wait Type", value: \.waitType) { Text($0.waitType).font(TypographyTokens.detail) }
            TableColumn("Time", value: \.waitTimeMsDelta) { Text("\($0.waitTimeMsDelta)ms").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning) }.width(70)
            TableColumn("Tasks", value: \.waitingTasksCountDelta) { Text("\($0.waitingTasksCountDelta)").font(TypographyTokens.detail) }.width(60)
        }
    }
}

struct MSSQLFileIOTable: View {
    let io: [SQLServerFileIOStatDelta]
    @Binding var sortOrder: [KeyPathComparator<SQLServerFileIOStatDelta>]
    
    private var sortedIO: [SQLServerFileIOStatDelta] {
        io.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedIO, sortOrder: $sortOrder) {
            TableColumn("DB", value: \.databaseId) { Text("\($0.databaseId)").font(TypographyTokens.detail) }.width(40)
            TableColumn("Read", value: \.bytesReadDelta) { Text("\($0.bytesReadDelta) b").font(TypographyTokens.detail) }
            TableColumn("Write", value: \.bytesWrittenDelta) { Text("\($0.bytesWrittenDelta) b").font(TypographyTokens.detail) }
            TableColumn("Stall", value: \.ioStallReadMsDelta) { Text("\($0.ioStallReadMsDelta)ms").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error) }.width(60)
        }
    }
}

struct MSSQLExpensiveQueriesTable: View {
    let queries: [SQLServerExpensiveQuery]
    @Binding var sortOrder: [KeyPathComparator<SQLServerExpensiveQuery>]
    let onPopout: (String) -> Void
    
    private var sortedQueries: [SQLServerExpensiveQuery] {
        queries.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedQueries, sortOrder: $sortOrder) {
            TableColumn("Query") { SQLQueryCell(sql: $0.sqlText ?? "", onPopout: onPopout) }
            TableColumn("Count", value: \.executionCount) { Text("\($0.executionCount)").font(TypographyTokens.detail) }.width(60)
            TableColumn("Worker Time", value: \.totalWorkerTime) { Text("\($0.totalWorkerTime)ms").font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent) }.width(90)
        }
    }
}

// MARK: - Postgres Tables

struct PostgresProcessesTable: View {
    let processes: [PostgresProcessInfo]
    @Binding var sortOrder: [KeyPathComparator<PostgresProcessInfo>]
    let onPopout: (String) -> Void
    let onKill: (Int) -> Void
    
    private var sortedProcesses: [PostgresProcessInfo] {
        processes.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedProcesses, sortOrder: $sortOrder) {
            TableColumn("PID", value: \.pid) { Text("\($0.pid)") }.width(min: 50, max: 70)
            TableColumn("DB") { Text($0.databaseName ?? "").font(TypographyTokens.detail) }.width(100)
            TableColumn("State") { StatusBadge(text: $0.state ?? "", isSystem: ($0.userName ?? "").isEmpty) }.width(90)
            TableColumn("Query") { 
                if let sql = $0.query, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                }
            }
        }
        .contextMenu(forSelectionType: PostgresProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button("Details") {
                    if let sql = process.query { onPopout(sql) }
                }
                .disabled(process.query == nil)
                
                Divider()
                
                Button("Kill Process", role: .destructive) {
                    onKill(Int(id))
                }
            }
        }
    }
}

struct PostgresWaitsTable: View {
    let waits: [PostgresWaitStatDelta]
    @Binding var sortOrder: [KeyPathComparator<PostgresWaitStatDelta>]
    
    private var sortedWaits: [PostgresWaitStatDelta] {
        waits.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedWaits, sortOrder: $sortOrder) {
            TableColumn("Type", value: \.waitEventType) { Text($0.waitEventType).font(TypographyTokens.detail) }
            TableColumn("Event", value: \.waitEvent) { Text($0.waitEvent).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning) }
            TableColumn("Δ Count", value: \.countDelta) { Text("\($0.countDelta)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent) }.width(70)
        }
    }
}

struct PostgresDBStatsTable: View {
    let stats: [PostgresDatabaseStatDelta]
    @Binding var sortOrder: [KeyPathComparator<PostgresDatabaseStatDelta>]
    
    private var sortedStats: [PostgresDatabaseStatDelta] {
        stats.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedStats, sortOrder: $sortOrder) {
            TableColumn("Database") { Text($0.datname).font(TypographyTokens.detail) }
            TableColumn("TX", value: \.xact_commit_delta) { Text("\($0.xact_commit_delta)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.success) }.width(60)
            TableColumn("Rollback", value: \.xact_rollback_delta) { Text("\($0.xact_rollback_delta)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error) }.width(70)
            TableColumn("IO Read", value: \.blks_read_delta) { Text("\($0.blks_read_delta)").font(TypographyTokens.detail) }.width(70)
        }
    }
}

struct PostgresExpensiveQueriesTable: View {
    let queries: [PostgresExpensiveQuery]
    @Binding var sortOrder: [KeyPathComparator<PostgresExpensiveQuery>]
    let onPopout: (String) -> Void
    
    private var sortedQueries: [PostgresExpensiveQuery] {
        queries.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedQueries, sortOrder: $sortOrder) {
            TableColumn("Query") { SQLQueryCell(sql: $0.query, onPopout: onPopout) }
            TableColumn("Calls", value: \.calls) { Text("\($0.calls)").font(TypographyTokens.detail) }.width(60)
            TableColumn("Total Time", value: \.total_exec_time) { Text(String(format: "%.1fms", $0.total_exec_time)).font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent) }.width(90)
            TableColumn("Rows", value: \.rows) { Text("\($0.rows)").font(TypographyTokens.detail) }.width(70)
        }
    }
}
