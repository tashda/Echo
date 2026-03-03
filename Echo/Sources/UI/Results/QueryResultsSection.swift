import SwiftUI
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Smoothly animates a counter from one value to another using SwiftUI animation
/// without tying increments to backend delivery cadence.
private struct AnimatedCounter: View {
    let targetValue: Int
    let isActive: Bool
    let formatter: (Int) -> String

    @State private var displayedValue: Double = 0
    @State private var previousTarget: Int = 0

    private func animationDuration(for delta: Int) -> Double {
        let perThousand: Double = 0.06
        let clamped = min(0.8, max(0.12, (Double(max(delta, 0)) / 1000.0) * perThousand))
        return clamped
    }

    var body: some View {
        Text(formatter(Int(displayedValue.rounded())))
            .font(.system(size: 11))
            .lineLimit(1)
            .onChange(of: targetValue) { _, new in
                guard isActive else {
                    displayedValue = Double(new)
                    previousTarget = new
                    return
                }
                let delta = abs(new - previousTarget)
                previousTarget = new
                withAnimation(.linear(duration: animationDuration(for: delta))) {
                    displayedValue = Double(new)
                }
            }
            .onAppear {
                displayedValue = Double(targetValue)
                previousTarget = targetValue
            }
    }
}

struct QueryResultsSection: View {
    @ObservedObject var query: QueryEditorState
    let connection: SavedConnection
    let activeDatabaseName: String?
    let gridState: QueryResultsGridState
    let isResizingResults: Bool
#if os(macOS)
    let foreignKeyDisplayMode: ForeignKeyDisplayMode
    let foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior
    let onForeignKeyEvent: (QueryResultsTableView.ForeignKeyEvent) -> Void
    let onJsonEvent: (QueryResultsTableView.JsonCellEvent) -> Void
#endif
    @State private var selectedTab: ResultTab = .results
    @State private var sortCriteria: SortCriteria?
    @State private var highlightedColumnIndex: Int?
    @State private var rowOrder: [Int] = []
    @State private var lastObservedColumnIDs: [String] = []
    @State private var showConnectionInfoPopover = false
    @State private var showRowInfoPopover = false
    @State private var showTimeInfoPopover = false
#if os(macOS)
    @State private var jsonInspectorContext: JsonInspectorContext?
#endif

    @EnvironmentObject private var themeManager: ThemeManager

    private let statusChipMinWidth: CGFloat = 52
    private let statusChipHeight: CGFloat = 28
    private let statusBarHeight: CGFloat = 36
    private let statusBarHorizontalPadding: CGFloat = 12
    private let statusBarChipSpacing: CGFloat = 4

#if os(macOS)
    private let rowCountChipWidth: CGFloat = 130
    private let timeChipWidth: CGFloat = 110
    private let statusChipWidth: CGFloat = 100
    private let modeChipWidth: CGFloat = 64
    private let statusBarContentYOffset: CGFloat = -2
    private var statusBarVerticalPadding: CGFloat {
        max(0, (statusBarHeight - statusChipHeight) / 2 - 3)
    }
#else
    private let connectionChipMinWidth: CGFloat = 180
    private let metricChipMinWidth: CGFloat = 82
    private let timeChipMinWidth: CGFloat = 112
#endif

    enum ResultTab: Hashable {
        case results
        case messages
#if os(macOS)
        case jsonInspector
#endif
    }

    var body: some View {
        VStack(spacing: 0) {
            if query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil {
                toolbar
                Divider().opacity(0.35)
                content
            } else {
                placeholder
            }
            statusBar
        }
        .background(ColorTokens.Background.primary)
        .onChange(of: query.resultChangeToken) { _, _ in
            handleResultTokenChange()
        }
        .onChange(of: query.errorMessage) { _, error in
            if error != nil {
                selectedTab = .messages
            }
        }
        .onChange(of: query.isExecuting) { _, executing in
            handleExecutionStateChange(isExecuting: executing)
        }
        .task {
            lastObservedColumnIDs = tableColumns.map(\.id)
            if activeSort != nil {
                rebuildRowOrder()
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                Text("Results").tag(ResultTab.results)
                Text("Messages").tag(ResultTab.messages)
#if os(macOS)
                if jsonInspectorContext != nil {
                    Text("JSON").tag(ResultTab.jsonInspector)
                }
#endif
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .labelsHidden()

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(ColorTokens.Background.primary)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if query.isExecuting && !hasRows {
                executingView
            } else if let error = query.errorMessage, !hasRows {
                errorView(error)
            } else {
                switch selectedTab {
                case .results:
                    resultsView
                case .messages:
                    messagesView
#if os(macOS)
                case .jsonInspector:
                    jsonInspectorView()
#endif
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(platformBackground)
    }

    private var resultsView: some View {
        Group {
            if hasRows {
#if os(macOS)
                QueryResultsTableView(
                    query: query,
                    highlightedColumnIndex: highlightedColumnIndex,
                    activeSort: activeSort,
                    rowOrder: rowOrder,
                    onColumnTap: toggleHighlightedColumn,
                    onSort: { index, action in
                        let column = tableColumns[index]
                        switch action {
                        case .ascending: applySort(column: column, ascending: true)
                        case .descending: applySort(column: column, ascending: false)
                        case .clear:
                            sortCriteria = nil
                            highlightedColumnIndex = nil
                            rebuildRowOrder()
                        }
                    },
                    onClearColumnHighlight: { highlightedColumnIndex = nil },
                    backgroundColor: NSColor(ColorTokens.Background.primary),
                    foreignKeyDisplayMode: foreignKeyDisplayMode,
                    foreignKeyInspectorBehavior: foreignKeyInspectorBehavior,
                    onForeignKeyEvent: onForeignKeyEvent,
                    onJsonEvent: { event in
                        if case .activate(let selection) = event {
                            openJsonInspector(with: selection)
                        }
                        onJsonEvent(event)
                    },
                    persistedState: gridState,
                    isResizing: isResizingResults
                )
#else
                QueryResultsGridView(
                    query: query,
                    rowOrder: rowOrder,
                    sortCriteria: activeSort,
                    onSort: { criteria in
                        sortCriteria = criteria
                        rebuildRowOrder()
                    }
                )
#endif
            } else {
                noRowsReturnedView
            }
        }
    }

    private var messagesView: some View {
        ResultMessagesView(results: query.results ?? QueryResultSet(columns: [], rows: []))
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Results Yet")
                .font(.headline)
            Text("Run a query to see data appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var executingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Executing query…")
                .font(.headline)
            Text("Please wait while we fetch your data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("Query Failed")
                .font(.headline)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var noRowsReturnedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Rows Returned")
                .font(.headline)
            Text("The query executed successfully but returned no data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
#if os(macOS)
        let shouldShowStatusBar = self.shouldShowStatusBar
        return Group {
            if shouldShowStatusBar {
                QueryResultsStatusBarContainer(
                    height: statusBarHeight,
                    verticalPadding: statusBarVerticalPadding,
                    contentOffset: statusBarContentYOffset,
                    background: ColorTokens.Background.primary,
                    dividerOpacity: 0.3
                ) {
                    HStack(alignment: .center, spacing: statusBarChipSpacing) {
                        connectionStatusChip
                        Spacer(minLength: 0)
                        HStack(alignment: .center, spacing: statusBarChipSpacing) {
                            modeChip
                            rowCountChip
                            executionTimeChip
                            queryStatusChip
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 18)
                    .padding(.vertical, statusBarVerticalPadding)
                }
                .background(ColorTokens.Background.primary)
                .frame(minHeight: statusBarHeight)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
#else
        HStack(spacing: 8) {
            connectionControl
            Spacer()
            rowCountControl
            timeControl
            statusControl
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ColorTokens.Background.primary)
#endif
    }

#if os(macOS)
    private var connectionStatusChip: some View {
        Button {
            showConnectionInfoPopover.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(connectionChipText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: statusChipHeight)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showConnectionInfoPopover, arrowEdge: .top) {
            connectionInfoPopover
        }
    }

    private var modeChip: some View {
        let isStreaming = query.isExecuting
        return HStack(spacing: 4) {
            Image(systemName: isStreaming ? "dot.radiowaves.left.and.right" : "Memory")
                .font(.system(size: 9, weight: .bold))
            Text(isStreaming ? "STREAM" : "LOCAL")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(isStreaming ? .orange : .secondary)
        .padding(.horizontal, 6)
        .frame(width: modeChipWidth, height: 20)
        .background(isStreaming ? Color.orange.opacity(0.1) : Color.primary.opacity(0.05), in: Capsule())
    }

    private var rowCountChip: some View {
        let progress = query.rowProgress
        let isExecuting = query.isExecuting
        return Button {
            if !isExecuting && progress.displayCount > 0 {
                showRowInfoPopover.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExecuting ? "arrow.triangle.2.circlepath" : "tablecells")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isExecuting ? .orange : .secondary)
                
                AnimatedCounter(
                    targetValue: progress.displayCount,
                    isActive: isExecuting,
                    formatter: { formatCompact($0) }
                )
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                
                Text("rows")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(width: rowCountChipWidth, height: statusChipHeight)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showRowInfoPopover, arrowEdge: .top) {
            rowInfoPopover
        }
    }

    private var executionTimeChip: some View {
        let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
        let hasDuration = query.isExecuting || query.lastExecutionTime != nil
        return Button {
            if !query.isExecuting && hasDuration {
                showTimeInfoPopover.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(query.isExecuting ? .orange : .secondary)
                Text(hasDuration ? formattedDuration(Int(elapsed.rounded())) : "—")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .frame(width: timeChipWidth, height: statusChipHeight)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTimeInfoPopover, arrowEdge: .top) {
            timeInfoPopover
        }
    }

    private var queryStatusChip: some View {
        let config = statusBubbleConfiguration()
        return HStack(spacing: 6) {
            Image(systemName: config.icon)
                .font(.system(size: 10, weight: .medium))
            Text(config.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(config.tint)
        .padding(.horizontal, 8)
        .frame(width: statusChipWidth, height: statusChipHeight)
        .background(config.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
#endif

    // MARK: - Logic

    private func handleResultTokenChange() {
        let newIDs = tableColumns.map(\.id)
        if newIDs != lastObservedColumnIDs {
            lastObservedColumnIDs = newIDs
            sortCriteria = nil
            highlightedColumnIndex = nil
        }
        rebuildRowOrder()
    }

    private func handleExecutionStateChange(isExecuting: Bool) {
        if isExecuting {
            sortCriteria = nil
            highlightedColumnIndex = nil
            rowOrder = []
        }
    }

    private func rebuildRowOrder() {
        let count = query.displayedRowCount
        guard count > 0 else {
            rowOrder = []
            return
        }

        guard let sort = activeSort,
              let columnIndex = tableColumns.firstIndex(where: { $0.name == sort.column }) else {
            rowOrder = []
            return
        }

        let column = tableColumns[columnIndex]
        let indices = Array(0..<count)
        rowOrder = indices.sorted { lhs, rhs in
            let result = compare(rowIndex: lhs, otherRowIndex: rhs, columnIndex: columnIndex, column: column)
            return sort.ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private var platformBackground: Color { ColorTokens.Background.primary }

#if os(macOS)
    private var gridBackgroundNSColor: NSColor {
        NSColor(ColorTokens.Background.tertiary)
    }
#endif

    private var shouldShowStatusBar: Bool {
        query.isExecuting || query.hasExecutedAtLeastOnce || query.errorMessage != nil
    }

    private var tableColumns: [ColumnInfo] {
        query.displayedColumns
    }

    private var hasRows: Bool {
        query.displayedRowCount > 0
    }

    private var activeSort: SortCriteria? {
        guard let sort = sortCriteria,
              tableColumns.contains(where: { $0.name == sort.column }) else {
            return nil
        }
        return sort
    }

    private var rowCount: Int {
        query.displayedRowCount
    }

    private func toggleHighlightedColumn(_ index: Int) {
        if highlightedColumnIndex == index {
            highlightedColumnIndex = nil
        } else {
            highlightedColumnIndex = index
        }
        rebuildRowOrder()
    }

    private func applySort(column: ColumnInfo, ascending: Bool) {
        sortCriteria = SortCriteria(column: column.name, ascending: ascending)
        if let index = tableColumns.firstIndex(where: { $0.id == column.id }) {
            highlightedColumnIndex = index
        }
        rebuildRowOrder()
    }

    private func statusBubbleConfiguration() -> (label: String, icon: String, tint: Color) {
        if query.isExecuting {
            return ("Executing", "bolt.fill", .orange)
        }
        if query.wasCancelled {
            return ("Cancelled", "stop.fill", .yellow)
        }
        if query.errorMessage != nil {
            return ("Error", "exclamationmark.triangle.fill", .red)
        }
        if query.hasExecutedAtLeastOnce {
            return ("Completed", "checkmark.circle.fill", .green)
        }
        return ("Ready", "clock", .secondary)
    }

    private func formatCompact(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000
            return millions >= 10 ? "\(Int(millions.rounded()))M" : String(format: "%.1fM", millions)
        }
        if value >= 100_000 {
            let thousands = value / 1_000
            return "\(thousands)K"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)m \(remainingSeconds)s"
    }

    private func rowValue(at rowIndex: Int, columnIndex: Int) -> String? {
        query.valueForDisplay(row: rowIndex, column: columnIndex)
    }

    private func compare(rowIndex lhs: Int, otherRowIndex rhs: Int, columnIndex: Int, column: ColumnInfo) -> ComparisonResult {
        let left = rowValue(at: lhs, columnIndex: columnIndex)
        let right = rowValue(at: rhs, columnIndex: columnIndex)
        return compare(left, right, column: column)
    }

    private func compare(_ lhs: String?, _ rhs: String?, column: ColumnInfo) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        if lhs == nil { return .orderedDescending }
        if rhs == nil { return .orderedAscending }

        guard let lhs, let rhs else { return .orderedSame }

        let trimmedLeft = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRight = rhs.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = column.dataType.lowercased()

        if isNumericType(type),
           let leftNumber = Decimal(string: trimmedLeft),
           let rightNumber = Decimal(string: trimmedRight) {
            if leftNumber == rightNumber { return .orderedSame }
            return leftNumber < rightNumber ? .orderedAscending : .orderedDescending
        }

        if type.contains("bool"),
           let leftBool = parseBool(trimmedLeft),
           let rightBool = parseBool(trimmedRight) {
            if leftBool == rightBool { return .orderedSame }
            return leftBool ? .orderedDescending : .orderedAscending
        }

        return trimmedLeft.caseInsensitiveCompare(trimmedRight)
    }

    private func isNumericType(_ type: String) -> Bool {
        type.contains("int") ||
        type.contains("serial") ||
        type.contains("numeric") ||
        type.contains("decimal") ||
        type.contains("float") ||
        type.contains("double") ||
        type.contains("money")
    }

    private func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "t", "1", "yes", "y":
            return true
        case "false", "f", "0", "no", "n":
            return false
        default:
            return nil
        }
    }

    private var connectionChipText: String {
        let serverName = connectionDisplayName
        guard let database = effectiveDatabaseName else { return serverName }
        return "\(serverName) • \(database)"
    }

    private var connectionDisplayName: String {
        let trimmedName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        let trimmedHost = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHost.isEmpty { return trimmedHost }
        return "Server"
    }

    private var effectiveDatabaseName: String? {
        if let provided = activeDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
            return provided
        }
        let fallback = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? nil : fallback
    }

    private var connectionInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)
            Text(connectionDisplayName)
        }
        .padding()
    }

    private var rowInfoPopover: some View {
        VStack {
            Text("\(query.rowProgress.displayCount) rows")
        }
        .padding()
    }

    private var timeInfoPopover: some View {
        VStack {
            Text("Duration")
        }
        .padding()
    }

#if os(macOS)
    private func openJsonInspector(with selection: QueryResultsTableView.JsonSelection) {
        selectedTab = .jsonInspector
    }

    @ViewBuilder
    private func jsonInspectorView() -> some View {
        Text("JSON Inspector")
    }

    private struct JsonInspectorContext: Equatable {
        let id = UUID()
    }
#endif
}

#if os(macOS)
struct QueryResultsStatusBarContainer<Content: View>: View {
    let height: CGFloat
    let verticalPadding: CGFloat
    let contentOffset: CGFloat
    let background: Color
    let dividerOpacity: Double
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(dividerOpacity)
            content()
                .frame(height: height)
                .offset(y: contentOffset)
        }
        .background(background)
    }
}
#endif
