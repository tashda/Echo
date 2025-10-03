import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct QueryResultsSection: View {
    @ObservedObject var query: QueryEditorState
    let connection: SavedConnection
    let activeDatabaseName: String?
    @State private var selectedTab: ResultTab = .results
    @State private var sortCriteria: SortCriteria?
    @State private var highlightedColumnIndex: Int?
    @State private var rowOrder: [Int] = []
#if !os(macOS)
    private struct CellSelection: Equatable {
        let row: Int
        let column: Int
    }
    @State private var selectedRow: Int?
    @State private var selectedCell: CellSelection?
#endif
    @State private var showConnectionInfoPopover = false
    @State private var showRowInfoPopover = false
    @State private var showTimeInfoPopover = false

    @EnvironmentObject private var themeManager: ThemeManager

    private let connectionChipMinWidth: CGFloat = 180
    private let metricChipMinWidth: CGFloat = 82
    private let timeChipMinWidth: CGFloat = 112
    private let statusChipMinWidth: CGFloat = 108
    private let statusBarHeight: CGFloat = 36
    private let statusChipHeight: CGFloat = 26

    enum ResultTab: Hashable {
        case results
        case messages
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
        .background(Color.clear)
        .onChange(of: query.results?.rows.count) { _, newCount in
            if newCount != nil {
                selectedTab = .results
                highlightedColumnIndex = nil
                rebuildRowOrder()
                showRowInfoPopover = false
                showTimeInfoPopover = false
#if !os(macOS)
                selectedRow = nil
                selectedCell = nil
#endif
            }
        }
        .onChange(of: query.errorMessage) { _, error in
            if error != nil {
                selectedTab = .messages
#if !os(macOS)
                selectedRow = nil
                selectedCell = nil
#endif
            }
        }
        .onChange(of: query.results?.columns.map(\.id)) { _, _ in
            highlightedColumnIndex = nil
            rebuildRowOrder()
#if !os(macOS)
            selectedRow = nil
            selectedCell = nil
#endif
        }
        .onChange(of: query.streamingColumns.map(\.id)) { _, _ in
            rebuildRowOrder()
        }
        .onChange(of: query.results?.commandTag) { _, _ in
            rebuildRowOrder()
#if !os(macOS)
            selectedRow = nil
            selectedCell = nil
#endif
        }
        .onChange(of: query.streamingRows.count) { _, newCount in
            if newCount > 0 {
                selectedTab = .results
            }
            if sortCriteria != nil {
                rebuildRowOrder()
            }
        }
        .onChange(of: query.displayedRowCount) { _, _ in
            if sortCriteria != nil {
                rebuildRowOrder()
            }
        }
        .task { rebuildRowOrder() }
        .onChange(of: query.isExecuting) { _, executing in
            if executing {
                sortCriteria = nil
                highlightedColumnIndex = nil
                rowOrder = []
                showRowInfoPopover = false
                showTimeInfoPopover = false
#if !os(macOS)
                selectedRow = nil
                selectedCell = nil
#endif
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                Text("Results").tag(ResultTab.results)
                Text("Messages").tag(ResultTab.messages)
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

    private var resultsView: some View {
#if os(macOS)
        return macResultsView
#else
        return swiftResultsView
#endif
    }

#if os(macOS)
    private var macResultsView: some View {
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
                MacResultsTable(
                    query: query,
                    highlightedColumnIndex: highlightedColumnIndex,
                    activeSort: activeSort,
                    rowOrder: rowOrder,
                    onColumnTap: { index in toggleHighlightedColumn(index) },
                    onSort: { index, action in handleSortAction(columnIndex: index, action: action) }
                )
            }
        }
    }
#endif

#if os(macOS)
    private func handleSortAction(columnIndex: Int, action: MacResultsTable.HeaderSortAction) {
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
                ScrollView([.horizontal]) {
                    VStack(spacing: 0) {
                        headerRow
                        Divider().opacity(0.35)
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                if rowOrder.count == rowCount {
                                    ForEach(rowOrder.indices, id: \.self) { position in
                                        dataRow(rowIndex: rowOrder[position], displayIndex: position)
                                    }
                                } else {
                                    ForEach(0..<rowCount, id: \.self) { position in
                                        dataRow(rowIndex: position, displayIndex: position)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
            }
        }
    }
#endif

#if !os(macOS)
    private var headerRow: some View {
        HStack(spacing: 0) {
            headerIndexCell

            ForEach(Array(tableColumns.enumerated()), id: \.element.id) { entry in
                columnHeader(for: entry.element, index: entry.offset)
                    .frame(minWidth: columnMinWidth(for: entry.offset), alignment: .leading)
                    .overlay(alignment: .trailing) {
                        if entry.offset < tableColumns.count - 1 {
                            Divider().opacity(0.2)
                        }
                    }
            }
        }
        .padding(.vertical, 6)
        .background(themeManager.windowBackground)
    }

    private var headerIndexCell: some View {
        Text("#")
            .font(.system(size: 12, weight: .semibold))
            .frame(width: indexColumnWidth, alignment: .trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(Divider().opacity(0.2), alignment: .trailing)
    }

    @ViewBuilder
    private func dataRow(rowIndex: Int, displayIndex: Int) -> some View {
        if rowIndex < rowCount {
            let isSelected = selectedRow == rowIndex

            HStack(spacing: 0) {
                Text("\(displayIndex + 1)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: indexColumnWidth, alignment: .trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(indexColumnBackground(isSelected: isSelected))
                    .overlay(Divider().opacity(0.08), alignment: .trailing)
                    .onTapGesture {
                        selectedRow = rowIndex
                        selectedCell = nil
                    }

                ForEach(0..<tableColumns.count, id: \.self) { columnIndex in
                    let value = query.valueForDisplay(row: rowIndex, column: columnIndex)
                    dataCell(value: value, rowIndex: rowIndex, columnIndex: columnIndex)
                        .frame(minWidth: columnMinWidth(for: columnIndex), alignment: .leading)
                        .overlay(alignment: .trailing) {
                            if columnIndex < tableColumns.count - 1 {
                                Divider().opacity(0.08)
                            }
                        }
                        .onTapGesture {
                            selectedCell = CellSelection(row: rowIndex, column: columnIndex)
                            selectedRow = nil
                        }
                }
            }
            .background(rowBackground(for: displayIndex, isSelected: isSelected))
            .onAppear {
                Task { @MainActor in
                    query.revealMoreRowsIfNeeded(forDisplayedRow: rowIndex)
                }
            }
        }
    }

    private func dataCell(value: String?, rowIndex: Int, columnIndex: Int) -> some View {
        let isHighlighted = highlightedColumnIndex == columnIndex
        let isSelected = selectedCell == CellSelection(row: rowIndex, column: columnIndex)

        let text: Text = {
            if let value {
                return Text(value)
                    .foregroundStyle(.primary)
            } else {
                return Text("NULL")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }()

        return text
            .font(.system(size: 12))
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(cellBackground(isHighlighted: isHighlighted, isSelected: isSelected))
            .contentShape(Rectangle())
    }

    private func rowBackground(for displayIndex: Int, isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        return displayIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.03)
    }

    private func indexColumnBackground(isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }
        return Color.secondary.opacity(0.08)
    }

    private func cellBackground(isHighlighted: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.22)
        }
        if isHighlighted {
            return Color.accentColor.opacity(0.12)
        }
        return Color.clear
    }

    private func columnMinWidth(for index: Int) -> CGFloat {
        guard index < tableColumns.count else { return 140 }
        let type = tableColumns[index].dataType.lowercased()

        if type.contains("bool") { return 90 }
        if isNumericType(type) { return 110 }
        if type.contains("date") || type.contains("time") { return 150 }
        return 180
    }

    private let indexColumnWidth: CGFloat = 56
#endif

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
        Group {
            if query.messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No Messages Yet")
                        .font(.headline)
                    Text("Server messages will appear here after your query runs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(query.messages) { message in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("#\(message.index)")
                                        .font(.system(size: 11, weight: .semibold))

                                    Text(message.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(message.severity.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(message.severity.tint)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(message.severity.tint.opacity(0.1), in: Capsule())
                                }

                                Text(message.message)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)

                                if !message.metadata.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(message.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                            Text("\(key): \(value)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

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
                    .frame(height: statusBarHeight, alignment: .center)
                    .padding(.horizontal, 18)
                }
                .background(themeManager.windowBackground)
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

#if os(macOS)
        return Button {
            showConnectionInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusBarHeight, alignment: .center)
        .contentShape(Rectangle())
        .popover(isPresented: $showConnectionInfoPopover, arrowEdge: .bottom) {
            connectionInfoPopover
        }
#else
        return Button {
            showConnectionInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusBarHeight, alignment: .center)
        .contentShape(Rectangle())
        .sheet(isPresented: $showConnectionInfoPopover) {
            connectionInfoPopover
        }
#endif
    }

    private var rowCountControl: some View {
        let total = query.totalAvailableRowCount
        let current = query.currentRowCount ?? rowCount
        let displayText = formattedRowCountShort(current, totalCount: total, executing: query.isExecuting)
        let textColor: Color = query.isExecuting ? .secondary : .primary
        let chip = metricChip(
            text: displayText,
            icon: "tablecells",
            tint: textColor,
            minWidth: metricChipMinWidth
        )

#if os(macOS)
        return Button {
            guard !query.isExecuting, total > 0 else { return }
            showRowInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusBarHeight, alignment: .center)
        .contentShape(Rectangle())
        .animation(.none, value: rowCount)
        .animation(.none, value: query.currentRowCount)
        .popover(isPresented: $showRowInfoPopover, arrowEdge: .bottom) {
            rowInfoPopover
        }
#else
        return Button {
            guard !query.isExecuting, total > 0 else { return }
            showRowInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusBarHeight, alignment: .center)
        .contentShape(Rectangle())
        .sheet(isPresented: $showRowInfoPopover) {
            rowInfoPopover
        }
#endif
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

#if os(macOS)
        return Button {
            guard !query.isExecuting, hasDuration else { return }
            showTimeInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusBarHeight, alignment: .center)
        .contentShape(Rectangle())
        .animation(.none, value: query.currentExecutionTime)
        .popover(isPresented: $showTimeInfoPopover, arrowEdge: .bottom) {
            timeInfoPopover
        }
#else
        return Button {
            guard !query.isExecuting, hasDuration else { return }
            showTimeInfoPopover.toggle()
        } label: {
            chip
        }
        .buttonStyle(.plain)
        .frame(height: statusBarHeight, alignment: .center)
        .contentShape(Rectangle())
        .sheet(isPresented: $showTimeInfoPopover) {
            timeInfoPopover
        }
#endif
    }

    private var statusControl: some View {
        let config = statusBubbleConfiguration()
        return metricChip(
            text: config.label,
            icon: config.icon,
            tint: config.tint,
            minWidth: statusChipMinWidth
        )
        .frame(height: statusBarHeight, alignment: .center)
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

    private func metricChip(text: String, icon: String, tint: Color, minWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
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

    private func formattedRowCountShort(_ displayed: Int, totalCount: Int, executing: Bool) -> String {
        if totalCount == 0 {
            return executing ? "\(displayed)" : "0"
        }
        if executing && displayed < totalCount {
            return "\(formatCompact(displayed))+"
        }
        return formatCompact(totalCount)
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
        let displayed = rowCount
        let total = query.totalAvailableRowCount
        let fetched = query.currentRowCount ?? total
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
        let totalRows = query.totalAvailableRowCount
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

    private var platformBackground: Color { themeManager.windowBackground }

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
