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
        // Keep it snappy; larger deltas animate slightly longer but remain quick.
        let perThousand: Double = 0.06 // ~60ms per 1k rows
        let clamped = min(0.8, max(0.12, (Double(max(delta, 0)) / 1000.0) * perThousand))
        return clamped
    }

    var body: some View {
        Text(formatter(Int(displayedValue.rounded())))
            .font(.system(size: 11))
            .lineLimit(1)
            .onChange(of: targetValue) { old, new in
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
    private let statusBarChipSpacing: CGFloat = 8

#if os(macOS)
    // Fixed widths for macOS to prevent shifting when content changes
    private let rowCountChipWidth: CGFloat = 130
    private let timeChipWidth: CGFloat = 110
    private let statusChipWidth: CGFloat = 100
    private let modeChipWidth: CGFloat = 72
    private let statusBarContentYOffset: CGFloat = -2 // Nudge chips up for visual centering
    private var statusBarVerticalPadding: CGFloat {
        // Nudge up by 3pt to center visually with the bottom window edge.
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
        .background(themeManager.windowBackground)
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
        .background(themeManager.windowBackground)
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

    @ViewBuilder
    private var overlayContent: some View {
        if query.isExecuting && !hasRows {
            executingView
                .background(platformBackground)
        } else if let error = query.errorMessage, !hasRows {
            errorView(error)
                .background(platformBackground)
        } else if !hasRows {
            if query.results != nil {
                noRowsReturnedView
                    .background(platformBackground)
            } else {
                placeholder
                    .background(platformBackground)
            }
        }
    }

    private var resultsView: some View {
#if os(macOS)
        return macResultsView
#else
        return swiftResultsView
#endif
    }

#if os(macOS)
    private var macResultsView: some View {
        ZStack {
            QueryResultsTableView(
                query: query,
                highlightedColumnIndex: highlightedColumnIndex,
                activeSort: activeSort,
                rowOrder: rowOrder,
                onColumnTap: { index in toggleHighlightedColumn(index) },
                onSort: { index, action in handleSortAction(columnIndex: index, action: action) },
                onClearColumnHighlight: { DispatchQueue.main.async { highlightedColumnIndex = nil } },
                backgroundColor: gridBackgroundColor,
                foreignKeyDisplayMode: foreignKeyDisplayMode,
                foreignKeyInspectorBehavior: foreignKeyInspectorBehavior,
                onForeignKeyEvent: onForeignKeyEvent,
                onJsonEvent: handleJsonCellEvent,
                persistedState: gridState,
                isResizing: isResizingResults
            )
            .opacity(hasRows ? 1 : 0)
            .allowsHitTesting(hasRows)

            overlayContent
        }
    }
#endif

#if os(macOS)
    private func handleSortAction(columnIndex: Int, action: QueryResultsTableView.HeaderSortAction) {
        guard columnIndex >= 0 else {
            sortCriteria = nil
            highlightedColumnIndex = nil
            rebuildRowOrder()
            return
        }

        switch action {
        case .ascending:
            applySort(column: tableColumns[columnIndex], ascending: true)
        case .descending:
            applySort(column: tableColumns[columnIndex], ascending: false)
        case .clear:
            sortCriteria = nil
            highlightedColumnIndex = nil
            rebuildRowOrder()
        }
    }
#endif

#if os(macOS)
    private func handleJsonCellEvent(_ event: QueryResultsTableView.JsonCellEvent) {
        switch event {
        case .selectionChanged:
            onJsonEvent(event)
        case .activate(let selection):
            openJsonInspector(with: selection)
            onJsonEvent(event)
        }
    }
#endif

#if !os(macOS)
    private var swiftResultsView: some View {
        Group {
            if rowCount == 0 {
                if query.results != nil {
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
                } else {
                    placeholder
                }
            } else {
                QueryResultsGridView(
                    query: query,
                    highlightedColumnIndex: highlightedColumnIndex,
                    activeSort: activeSort,
                    rowOrder: rowOrder,
                    onColumnTap: { index in toggleHighlightedColumn(index) },
                    onSort: handleGridSortAction,
                    onClearColumnHighlight: { highlightedColumnIndex = nil },
                    gridState: gridState
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func handleGridSortAction(columnIndex: Int, action: ResultGridSortAction) {
        switch action {
        case .ascending(let index):
            guard index >= 0, index < tableColumns.count else { return }
            applySort(column: tableColumns[index], ascending: true)
        case .descending(let index):
            guard index >= 0, index < tableColumns.count else { return }
            applySort(column: tableColumns[index], ascending: false)
        case .clear:
            sortCriteria = nil
            highlightedColumnIndex = nil
            rebuildRowOrder()
        }
    }
#endif

    private func handleResultTokenChange() {
        if query.displayedRowCount > 0 {
            selectedTab = .results
        }

        showRowInfoPopover = false
        showTimeInfoPopover = false

        let newColumnIDs = tableColumns.map(\.id)
        if newColumnIDs != lastObservedColumnIDs {
            lastObservedColumnIDs = newColumnIDs
            highlightedColumnIndex = nil
#if os(macOS)
            jsonInspectorContext = nil
#endif
        }

        if activeSort != nil {
            rebuildRowOrder()
        } else if !rowOrder.isEmpty {
            rowOrder = []
        }
    }

    private func handleExecutionStateChange(isExecuting: Bool) {
        guard isExecuting else { return }
        sortCriteria = nil
        highlightedColumnIndex = nil
        rowOrder = []
        showRowInfoPopover = false
        showTimeInfoPopover = false
#if os(macOS)
        if selectedTab == .jsonInspector {
            selectedTab = .results
        }
        jsonInspectorContext = nil
#endif
    }

    private func rebuildRowOrder() {
        guard let sort = activeSort,
              let columnIndex = tableColumns.firstIndex(where: { $0.name == sort.column }) else {
            rowOrder = []
            return
        }

        let columnInfo = tableColumns[columnIndex]
        let total = rowCount
        var indices = Array(0..<total)
        indices.sort { lhs, rhs in
            let comparison = compare(rowIndex: lhs, otherRowIndex: rhs, columnIndex: columnIndex, column: columnInfo)
            if comparison == .orderedSame {
                return lhs < rhs
            }
            return sort.ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
        rowOrder = indices
    }

    private var messagesView: some View {
        ResultMessagesView(results: query.results ?? QueryResultSet(columns: [], rows: []))
    }

#if os(macOS)
    private var statusBar: some View {
        Group {
            if shouldShowStatusBar {
                QueryResultsStatusBarContainer(
                    height: statusBarHeight,
                    verticalPadding: statusBarVerticalPadding,
                    contentOffset: statusBarContentYOffset,
                    background: themeManager.windowBackground,
                    dividerOpacity: 0.3
                ) {
                    HStack(alignment: .center, spacing: statusBarChipSpacing) {
                        connectionStatusChip
                        Spacer(minLength: 0)
                        HStack(spacing: statusBarChipSpacing) {
                            modeStatusChip
                            rowCountStatusChip
                            timeStatusChip
                            statusSummaryChip
                        }
                    }
                    .padding(.horizontal, statusBarHorizontalPadding)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var connectionStatusChip: some View {
        statusBarChipButton {
            showConnectionInfoPopover.toggle()
        } label: {
            Image(systemName: "server.rack")
                .font(.system(size: 11))
                .foregroundStyle(connection.color)

            Text(connectionDisplayName)
                .font(.system(size: 11))
                .layoutPriority(1)
                .lineLimit(1)

            if let database = effectiveDatabaseName {
                Text(database)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
            }
        }
        .popover(isPresented: $showConnectionInfoPopover, arrowEdge: .bottom) {
            connectionInfoPopover
        }
    }

    private var rowCountStatusChip: some View {
        let progress = query.rowProgress
        let isExecuting = query.isExecuting
        let isEnabled = !isExecuting && progress.displayCount > 0

        return statusBarChipButton(width: rowCountChipWidth) {
            guard isEnabled else { return }
            showRowInfoPopover.toggle()
        } label: {
            HStack(spacing: 6) {
                statusIcon(named: "tablecells")

                // Animated counter that smoothly counts up
                if isExecuting && progress.displayCount > 0 {
                    AnimatedCounter(
                        targetValue: progress.displayCount,
                        isActive: isExecuting,
                        formatter: { formatCompact($0) }
                    )
                    .foregroundStyle(.secondary)
                } else if isExecuting {
                    Text("…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(formatCompact(progress.displayCount))
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
        }
        .disabled(!isEnabled)
        .popover(isPresented: $showRowInfoPopover, arrowEdge: .bottom) {
            rowInfoPopover
        }
    }

    private var timeStatusChip: some View {
        let elapsedSeconds = query.isExecuting
            ? max(0, Int(query.currentExecutionTime))
            : max(0, Int((query.lastExecutionTime ?? 0)))
        let hasDuration = query.isExecuting || query.lastExecutionTime != nil
        let displayText = hasDuration ? formattedDuration(elapsedSeconds) : "—"
        let textColor: Color = query.isExecuting ? .orange : (hasDuration ? .primary : .secondary)
        let isEnabled = hasDuration && !query.isExecuting

        return statusBarChipButton(width: timeChipWidth) {
            guard isEnabled else { return }
            showTimeInfoPopover.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(textColor)
                Text(displayText)
                    .font(.system(size: 11))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
        }
        .disabled(!isEnabled)
        .popover(isPresented: $showTimeInfoPopover, arrowEdge: .bottom) {
            timeInfoPopover
        }
    }

    private var modeStatusChip: some View {
        statusBarChip(width: modeChipWidth) {
            Menu {
                Button(action: { query.streamingModeOverride = .auto }) {
                    HStack { if query.streamingModeOverride == .auto { Image(systemName: "checkmark") }; Text("Auto") }
                }
                Button(action: { query.streamingModeOverride = .simple }) {
                    HStack { if query.streamingModeOverride == .simple { Image(systemName: "checkmark") }; Text("Simple") }
                }
                Button(action: { query.streamingModeOverride = .cursor }) {
                    HStack { if query.streamingModeOverride == .cursor { Image(systemName: "checkmark") }; Text("Cursor") }
                }
            } label: {
                Text(query.streamingModeOverride.displayName)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    private var statusSummaryChip: some View {
        let config = statusBubbleConfiguration()
        let isExecuting = query.isExecuting
        return statusBarChip(width: statusChipWidth) {
            if isExecuting {
                if #available(macOS 14.0, iOS 17.0, *) {
                    Image(systemName: "progress.indicator")
                        .font(.system(size: 11))
                        .symbolEffect(.rotate, isActive: isExecuting)
                        .foregroundStyle(config.tint)
                } else {
                    Image(systemName: "progress.indicator")
                        .font(.system(size: 11))
                        .foregroundStyle(config.tint)
                }
            } else {
                Image(systemName: config.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(config.tint)
            }
            Text(config.label)
                .font(.system(size: 11))
                .foregroundStyle(config.tint)
                .lineLimit(1)
        }
    }

    private func statusIcon(named name: String) -> some View {
        let image: Image
        if let _ = NSImage(named: NSImage.Name(name)) {
            image = Image(name)
        } else {
            image = Image(systemName: "tablecells")
        }
        return image
            .font(.system(size: 11))
            .foregroundStyle(Color.primary)
    }

    private func statusBarChipButton<Label: View>(
        width: CGFloat? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) -> some View {
        Button(action: action) {
            statusBarChip(width: width, content: label)
        }
        .buttonStyle(.plain)
        .frame(height: statusChipHeight, alignment: .center)
    }

    @ViewBuilder
    private func statusBarChip<Content: View>(
        width: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        StatusBarChipContainer(
            width: width,
            height: statusChipHeight,
            content: content
        )
    }

    private struct StatusBarChipContainer<Content: View>: View {
        let width: CGFloat?
        let height: CGFloat
        private let contentBuilder: () -> Content

        init(
            width: CGFloat?,
            height: CGFloat,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.width = width
            self.height = height
            self.contentBuilder = content
        }

        var body: some View {
            ZStack(alignment: .center) {
                HStack(spacing: 6) {
                    contentBuilder()
                }
                .padding(.horizontal, 8)
                .frame(height: height, alignment: .center)
            }
            .frame(height: height, alignment: .center)
            .frame(width: width, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private struct QueryResultsStatusBarContainer<Content: View>: View {
        let height: CGFloat
        let verticalPadding: CGFloat
        let contentOffset: CGFloat
        let background: Color
        let dividerOpacity: Double
        @ViewBuilder var content: () -> Content

        var body: some View {
            ZStack(alignment: .center) {
                background
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.vertical, verticalPadding)
                    .offset(y: contentOffset)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .top) {
                Divider().opacity(dividerOpacity)
            }
        }
    }
#else
    private var statusBar: some View {
        Group {
            if query.isExecuting || query.hasExecutedAtLeastOnce {
                VStack(spacing: 0) {
                    Divider().opacity(0.3)
                    HStack(alignment: .center, spacing: 16) {
                        connectionControl
                        Spacer(minLength: 0)
                        rowCountControl
                        timeControl
                        statusControl
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 18)
                    .padding(.vertical, statusBarVerticalPadding)
                }
                .background(themeManager.windowBackground)
                .frame(minHeight: statusBarHeight, alignment: .center)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var connectionControl: some View {
        let chip = metricChip(
            text: connectionChipText,
            icon: connectionIconName,
            tint: connectionChipTint,
            minWidth: connectionChipMinWidth
        )

        return Button {
            showConnectionInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusChipHeight, alignment: .center)
        .contentShape(Rectangle())
        .sheet(isPresented: $showConnectionInfoPopover) {
            connectionInfoPopover
        }
    }

    private var rowCountControl: some View {
        let progress = query.rowProgress
        let isExecuting = query.isExecuting
        let textColor: Color = isExecuting ? .secondary : .primary

        // Use animated icon during execution
        let iconName = isExecuting ? "progress.indicator" : "tablecells"

        return Button {
            guard !isExecuting, progress.displayCount > 0 else { return }
            showRowInfoPopover.toggle()
        } label: {
            HStack(spacing: 6) {
                if isExecuting {
                    if #available(macOS 14.0, iOS 17.0, *) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(textColor)
                            .symbolEffect(.rotate, isActive: isExecuting)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(textColor)
                    }
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textColor)
                }

                // Animated counter for smooth counting effect
                if isExecuting && progress.displayCount > 0 {
                    HStack(spacing: 2) {
                        AnimatedCounter(
                            targetValue: progress.displayCount,
                            isActive: isExecuting,
                            formatter: { formatCompact($0) }
                        )
                        .foregroundStyle(textColor)

                        Text("+")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(textColor)
                    }
                } else if isExecuting {
                    Text("…")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(textColor)
                } else {
                    Text(formatCompact(progress.displayCount))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(textColor)
                }
            }
            .frame(height: statusChipHeight, alignment: .center)
            .padding(.horizontal, 9)
            .frame(minWidth: metricChipMinWidth, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                    )
            )
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .frame(height: statusChipHeight, alignment: .center)
        .contentShape(Rectangle())
        .sheet(isPresented: $showRowInfoPopover) {
            rowInfoPopover
        }
    }

    private var timeControl: some View {
        let elapsedSeconds = query.isExecuting
            ? max(0, Int(query.currentExecutionTime))
            : max(0, Int((query.lastExecutionTime ?? 0)))
        let hasDuration = query.isExecuting || query.lastExecutionTime != nil
        let displayText = hasDuration ? formattedDuration(elapsedSeconds) : "—"
        let textColor: Color = query.isExecuting ? .orange : (hasDuration ? .primary : .secondary)
        let chip = metricChip(
            text: displayText,
            icon: "clock",
            tint: textColor,
            minWidth: timeChipMinWidth
        )

        return Button {
            guard !query.isExecuting, hasDuration else { return }
            showTimeInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusChipHeight, alignment: .center)
        .contentShape(Rectangle())
        .sheet(isPresented: $showTimeInfoPopover) {
            timeInfoPopover
        }
    }

    private var statusControl: some View {
        let config = statusBubbleConfiguration()
        return metricChip(
            text: config.label,
            icon: config.icon,
            tint: config.tint,
            minWidth: statusChipMinWidth
        )
        .frame(height: statusChipHeight, alignment: .center)
    }

    private var connectionChipText: String {
        let serverName = connectionDisplayName
        guard let database = effectiveDatabaseName else { return serverName }
        return "\(serverName) • \(database)"
    }

    private var connectionChipTint: Color {
        Color.primary
    }

    private var connectionIconName: String {
        "server.rack"
    }
#endif

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

    private var connectionURLString: String {
        let trimmedHost = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        switch connection.databaseType {
        case .sqlite:
            if !trimmedHost.isEmpty {
                return trimmedHost
            }
            if let database = effectiveDatabaseName, !database.isEmpty {
                return database
            }
            return "sqlite://local"
        default:
            guard !trimmedHost.isEmpty else { return "—" }
            var url = "\(connection.databaseType.rawValue)://\(trimmedHost)"
            if connection.port > 0 {
                url += ":\(connection.port)"
            }
            if let database = effectiveDatabaseName, !database.isEmpty {
                url += "/\(database)"
            }
            return url
        }
    }

    private var connectionUserText: String {
        let trimmedUser = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUser.isEmpty ? "—" : trimmedUser
    }

    private var connectionVersionText: String {
        if let version = connection.serverVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
            return version
        }
        return connection.databaseType.displayName
    }

    private var connectionInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.title3.weight(.semibold))
            infoRow("Name", value: connectionDisplayName)
            if let database = effectiveDatabaseName {
                infoRow("Database", value: database)
            }
            infoRow("URL", value: connectionURLString)
            infoRow("User", value: connectionUserText)
            infoRow("Version", value: connectionVersionText)
        }
        .padding(18)
        .frame(minWidth: 260, alignment: .leading)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
    }

#if !os(macOS)
    private func metricChip(text: String, icon: String, tint: Color, minWidth: CGFloat, animateIcon: Bool = false) -> some View {
        HStack(spacing: 6) {
            if animateIcon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
                    .symbolEffect(.rotate.continuous, isActive: animateIcon)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(height: statusChipHeight, alignment: .center)
        .padding(.horizontal, 9)
        .frame(minWidth: minWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        )
        .frame(maxHeight: .infinity, alignment: .center)
    }
#endif

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

    private func formattedRowDetail(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) " + (seconds == 1 ? "second" : "seconds")
        }
        if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            let minutePart = "\(minutes) min" + (minutes == 1 ? "" : "s")
            if remainingSeconds == 0 {
                return minutePart
            }
            let secondPart = "\(remainingSeconds) second" + (remainingSeconds == 1 ? "" : "s")
            return minutePart + " and " + secondPart
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let hourPart = "\(hours) hour" + (hours == 1 ? "" : "s")
        if minutes == 0 {
            return hourPart
        }
        let minutePart = "\(minutes) minute" + (minutes == 1 ? "" : "s")
        return hourPart + " and " + minutePart
    }

    private func formattedExactDuration(_ seconds: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let value = formatter.string(from: NSNumber(value: seconds)) ?? String(format: "%.2f", seconds)
        return "\(value) seconds"
    }

    private var rowInfoPopover: some View {
        let total = max(query.rowProgress.totalReported, query.rowProgress.materialized)
        let fetched = query.rowProgress.materialized
        let displayValue: String
        if query.isExecuting {
            displayValue = "\(formattedRowDetail(fetched)) rows fetched so far"
        } else {
            displayValue = "\(formattedRowDetail(total)) rows returned"
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(displayValue)
                .font(.title3.weight(.semibold))
        }
        .padding(18)
        .frame(minWidth: 210)
    }

    private var timeInfoPopover: some View {
        let elapsed = query.lastExecutionTime ?? query.currentExecutionTime
        let precise = formattedExactDuration(elapsed)
        let summary = formattedDuration(Int(elapsed.rounded()))
        let totalRows = max(query.rowProgress.totalReported, query.rowProgress.materialized)
        let rateString: String?
        if elapsed > 0 && totalRows > 0 && !query.isExecuting {
            let rate = Double(totalRows) / elapsed
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            formatter.numberStyle = .decimal
            if let value = formatter.string(from: NSNumber(value: rate)) {
                rateString = "\(value) rows/sec"
            } else {
                rateString = nil
            }
        } else {
            rateString = nil
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(summary.capitalized)
                .font(.title3.weight(.semibold))
            Text(precise)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let rateString {
                Text(rateString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(minWidth: 210)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

#if os(macOS)
    private func openJsonInspector(with selection: QueryResultsTableView.JsonSelection) {
        let summary = jsonRowSummary(for: selection)
        let rootNode = selection.jsonValue.toOutlineNode()
        jsonInspectorContext = JsonInspectorContext(
            columnName: selection.columnName,
            rowSummary: summary,
            root: rootNode
        )
        selectedTab = .jsonInspector
    }

    @ViewBuilder
    private func jsonInspectorView() -> some View {
        if let context = jsonInspectorContext {
            let background = Color(nsColor: gridBackgroundColor)
            VStack(alignment: .leading, spacing: 16) {
                JsonInspectorHeader(context: context)
                JsonOutlineContainer(root: context.root)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(background)
        } else {
            JsonInspectorEmptyView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func jsonRowSummary(for selection: QueryResultsTableView.JsonSelection) -> String {
        if let descriptor = primaryKeyDescriptor(for: selection) {
            return descriptor
        }
        return "Row \(selection.displayedRowIndex + 1)"
    }

    private func primaryKeyDescriptor(for selection: QueryResultsTableView.JsonSelection) -> String? {
        guard let index = tableColumns.firstIndex(where: { $0.isPrimaryKey }),
              index < tableColumns.count else {
            return nil
        }
        guard let raw = query.valueForDisplay(row: selection.sourceRowIndex, column: index) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(tableColumns[index].name): \(trimmed)"
    }

    private struct JsonInspectorContext: Equatable {
        let columnName: String
        let rowSummary: String
        let root: JsonOutlineNode

        var valueKind: JsonValue.Kind { root.value.kind }
        var isContainer: Bool { root.value.isContainer }

        var summaryLine: String {
            switch root.value.kind {
            case .object, .array:
                return "\(valueKind.displayName) • \(root.value.summary)"
            default:
                return "\(valueKind.displayName) • \(JsonInspectorContext.preview(for: root.value, limit: 80))"
            }
        }

        static func preview(for value: JsonValue, limit: Int = 160) -> String {
            let raw: String
            switch value {
            case .object(let entries):
                let count = entries.count
                raw = count == 1 ? "1 key" : "\(count) keys"
            case .array(let values):
                let count = values.count
                raw = count == 1 ? "1 item" : "\(count) items"
            case .string(let text):
                raw = "\"\(text)\""
            case .number(let number):
                raw = number
            case .bool(let flag):
                raw = flag ? "true" : "false"
            case .null:
                raw = "null"
            }
            return truncated(raw, limit: limit)
        }

        private static func truncated(_ text: String, limit: Int) -> String {
            guard text.count > limit else { return text }
            let index = text.index(text.startIndex, offsetBy: limit)
            return String(text[text.startIndex..<index]) + "…"
        }
    }

    private struct JsonInspectorHeader: View {
        let context: JsonInspectorContext

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(context.columnName)
                    .font(.title3.weight(.semibold))
                Text(context.rowSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(context.summaryLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct JsonOutlineContainer: View {
        let root: JsonOutlineNode

        var body: some View {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: NSColor.controlBackgroundColor))
                ScrollView {
                    VStack(spacing: 0) {
                        JsonOutlineNodeView(node: root, depth: 0, isRoot: true)
                    }
                    .padding(.vertical, 8)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
            )
        }
    }

    private struct JsonOutlineNodeView: View {
        let node: JsonOutlineNode
        let depth: Int
        let isRoot: Bool

        @State private var isExpanded: Bool

        init(node: JsonOutlineNode, depth: Int, isRoot: Bool = false) {
            self.node = node
            self.depth = depth
            self.isRoot = isRoot
            _isExpanded = State(initialValue: node.value.isContainer)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                row
                if node.value.isContainer && isExpanded {
                    VStack(spacing: 0) {
                        ForEach(node.children) { child in
                            JsonOutlineNodeView(node: child, depth: depth + 1)
                        }
                    }
                }
            }
        }

        private var row: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                toggleIcon
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard node.value.isContainer else { return }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isExpanded.toggle()
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let title = node.key.displayTitle, !title.isEmpty {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        } else if isRoot {
                            Text("JSON")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        JsonTypeBadge(kind: node.value.kind)
                    }

                    Text(JsonInspectorContext.preview(for: node.value))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(valueColor)
                        .lineLimit(node.value.isContainer ? 1 : 4)
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, CGFloat(depth) * 16 + 12)
            .padding(.trailing, 12)
            .background(rowBackground)
            .contentShape(Rectangle())
            .onTapGesture {
                guard node.value.isContainer else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            }
        }

        private var toggleIcon: some View {
            Group {
                if node.value.isContainer {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 2)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6, weight: .bold))
                        .opacity(0)
                }
            }
        }

        private var valueColor: Color {
            switch node.value.kind {
            case .object, .array:
                return .secondary
            case .string:
                return JsonTypeBadge.color(for: .string)
            case .number:
                return JsonTypeBadge.color(for: .number)
            case .boolean:
                return JsonTypeBadge.color(for: .boolean)
            case .null:
                return JsonTypeBadge.color(for: .null)
            }
        }

        private var rowBackground: Color {
            isRoot ? Color.primary.opacity(0.02) : Color.clear
        }
    }

    private struct JsonTypeBadge: View {
        let kind: JsonValue.Kind

        var body: some View {
            Text(kind.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule(style: .continuous))
        }

        var color: Color { Self.color(for: kind) }

        static func color(for kind: JsonValue.Kind) -> Color {
            switch kind {
            case .object, .array:
                return Color.teal
            case .string:
                return Color.blue
            case .number:
                return Color.purple
            case .boolean:
                return Color.orange
            case .null:
                return Color.gray
            }
        }
    }

    private struct JsonInspectorEmptyView: View {
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No JSON Data")
                    .font(.headline)
                Text("Double-click a JSON column to explore its structure here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
#endif

    private var platformBackground: Color { themeManager.windowBackground }
#if os(macOS)
    private var gridBackgroundColor: NSColor {
        themeManager.resultsGridCellBackgroundNSColor
    }
#else
    private var gridBackgroundColor: Color {
        themeManager.resultsGridBackground
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

    private func columnHeader(for column: ColumnInfo, index: Int) -> some View {
        let isHighlighted = highlightedColumnIndex == index
        let isSorted = activeSort?.column == column.name
        let sortSymbol = activeSort?.ascending == true ? "arrow.up" : "arrow.down"

        return Button {
            toggleHighlightedColumn(index)
        } label: {
            HStack(spacing: 4) {
                Text(column.name)
                    .font(.system(size: 12, weight: .semibold))
                if isSorted {
                    Image(systemName: sortSymbol)
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHighlighted ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                applySort(column: column, ascending: true)
            } label: {
                menuItemLabel(
                    "Sort Ascending",
                    systemImage: "arrow.up",
                    isActive: isSorted && (activeSort?.ascending ?? false)
                )
            }
            Button {
                applySort(column: column, ascending: false)
            } label: {
                menuItemLabel(
                    "Sort Descending",
                    systemImage: "arrow.down",
                    isActive: isSorted && !(activeSort?.ascending ?? true)
                )
            }
            if isSorted {
                Divider()
                Button {
                    sortCriteria = nil
                    highlightedColumnIndex = nil
                    rebuildRowOrder()
                } label: {
                    menuItemLabel("Clear Sort", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private func toggleHighlightedColumn(_ index: Int) {
        if highlightedColumnIndex == index {
            highlightedColumnIndex = nil
        } else {
            highlightedColumnIndex = index
        }
    }

    private func applySort(column: ColumnInfo, ascending: Bool) {
        sortCriteria = SortCriteria(column: column.name, ascending: ascending)
        if let index = tableColumns.firstIndex(where: { $0.id == column.id }) {
            highlightedColumnIndex = index
        }
        rebuildRowOrder()
    }

    private func menuItemLabel(_ title: String, systemImage: String, isActive: Bool = false) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
            Spacer(minLength: 6)
            if isActive {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
            }
        }
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
}
