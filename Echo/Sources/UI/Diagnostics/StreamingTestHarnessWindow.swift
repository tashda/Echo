import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct StreamingTestHarnessWindow: Scene {
    static let sceneID = "streaming-test-harness"

    var body: some Scene {
        Window("Streaming Test Harness", id: Self.sceneID) {
            StreamingTestHarnessView()
                .environment(AppCoordinator.shared.projectStore)
                .environment(AppCoordinator.shared.connectionStore)
                .environment(AppCoordinator.shared.navigationStore)
                .environmentObject(AppCoordinator.shared.appModel)
                .environmentObject(AppCoordinator.shared.themeManager)
        }
        .defaultSize(width: 840, height: 620)
    }
}

private struct StreamingTestHarnessView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var coordinator = AppCoordinator.shared

    @State private var selectedSessionID: UUID?
    @State private var sqlInput: String = "SELECT current_timestamp;"
    @State private var isRunning = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var logs: [StreamingLogEntry] = []
    @State private var report: QueryPerformanceTracker.Report?
    @State private var runTask: Task<Void, Never>?
    @State private var tracker: QueryPerformanceTracker = QueryPerformanceTracker(initialBatchTarget: 512)
    @State private var logFilter: LogVisibility = .simple
    @State private var pendingDebugLogs: [StreamingLogEntry] = []
    @State private var debugFlushTask: Task<Void, Never>?
    @State private var debugAggregator = DebugLogAggregator()

    private var availableSessions: [ConnectionSession] {
        guard coordinator.isInitialized else { return [] }
        return appModel.sessionManager.sortedSessions
    }

    private var selectedSession: ConnectionSession? {
        guard let id = selectedSessionID else { return availableSessions.first }
        return availableSessions.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .onAppear {
            if selectedSessionID == nil {
                selectedSessionID = availableSessions.first?.id
            }
        }
        .onChange(of: logFilter) { _, newValue in
            if newValue == .debug {
                flushPendingDebugLogs(immediate: true)
            } else {
                pendingDebugLogs.removeAll(keepingCapacity: true)
                debugFlushTask?.cancel()
                debugFlushTask = nil
                debugAggregator.reset()
            }
        }
        .onChange(of: availableSessions.count) { _, _ in
            guard let session = selectedSession else {
                selectedSessionID = availableSessions.first?.id
                return
            }
            if !availableSessions.contains(where: { $0.id == session.id }) {
                selectedSessionID = availableSessions.first?.id
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streaming Test Harness")
                .font(.title2.bold())
            Text("Execute diagnostic queries without the results grid to inspect streaming performance, batching, and driver throughput.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var content: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                sessionPicker
                sqlEditor
                controlButtons
                statusIndicators
                Spacer()
            }
            .frame(width: 320)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                reportSection
                Divider()
                logSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(24)
    }

    private var sessionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connection")
                .font(.caption)
                .foregroundStyle(.secondary)
            if availableSessions.isEmpty {
                Text("No active connections.\nOpen a connection first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Connection", selection: Binding(
                    get: { selectedSessionID ?? availableSessions.first?.id ?? UUID() },
                    set: { value in selectedSessionID = value }
                )) {
                    ForEach(availableSessions) { session in
                        Text(session.displayName)
                            .tag(session.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var sqlEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SQL")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $sqlInput)
                .font(.system(.body, design: .monospaced))
                .lineSpacing(4)
                .disableAutocorrection(true)
                .frame(minHeight: 140, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button {
                runStreamingTest()
            } label: {
                Label("Run Test", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning || selectedSession == nil || sqlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                cancelRunningTest()
            } label: {
                Label("Cancel", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(!isRunning)
        }
    }

    private var statusIndicators: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isRunning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Running query…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = statusMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reportSection: some View {
        Group {
            if let report {
                StreamingReportSummary(report: report)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Results")
                        .font(.headline)
                    Text("Run a test to view timings and batch metrics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stream Log")
                    .font(.headline)
                Spacer()
                Picker("", selection: $logFilter) {
                    ForEach(LogVisibility.allCases) { visibility in
                        Text(visibility.title).tag(visibility)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                Button("Copy Log") {
                    copyLogsToClipboard()
                }
                .disabled(filteredLogs.isEmpty)
                Button("Clear") {
                    logs.removeAll()
                }
                .disabled(logs.isEmpty || isRunning)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(filteredLogs) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(entry.message)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(12)
            }
            .frame(minHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(themeManager.surfaceBackgroundColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.6 : 0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func runStreamingTest() {
        guard let session = selectedSession else {
            errorMessage = "Select a connection before running the test."
            return
        }

        flushPendingDebugLogs(immediate: true)
        pendingDebugLogs.removeAll(keepingCapacity: true)
        cancelRunningTest()

        let sql = sqlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else {
            errorMessage = "Enter a SQL statement to execute."
            return
        }

        logs.removeAll()
        errorMessage = nil
        statusMessage = nil
        report = nil
        isRunning = true
        debugAggregator.reset()
        appendLog("[Start] Executing diagnostic query (\(sql.count) chars).", debug: false)

        let initialBatchTarget = max(100, projectStore.globalSettings.resultsInitialRowLimit)
        let newTracker = QueryPerformanceTracker(initialBatchTarget: initialBatchTarget)
        tracker = newTracker
        tracker.reset()
        tracker.markQueryDispatched()

        let runStart = CFAbsoluteTimeGetCurrent()

        runTask = Task {
            do {
                let result = try await session.session.simpleQuery(sql) { update in
                    Task { @MainActor in
                        handleStreamUpdate(update)
                    }
                }

                let rowCount = result.totalRowCount ?? result.rows.count
                await MainActor.run {
                    tracker.markResultSetReceived(totalRowCount: rowCount)
                    let finalReport = tracker.finalize(cancelled: false, finalRowCount: rowCount, estimatedMemoryBytes: nil)
                    report = finalReport
                    statusMessage = "Completed in \(Self.formattedDuration(CFAbsoluteTimeGetCurrent() - runStart))."
                    isRunning = false
                    appendLog("[Complete] rows=\(rowCount) batches=\(finalReport.batchCount)", debug: false)
                    appendLog(
                        "[Report] firstBatch=\(finalReport.firstBatchSize ?? 0) largestBatch=\(finalReport.largestBatchSize) totalRows=\(finalReport.totalRows)",
                        debug: false
                    )
                    flushDebugSummaries()
                    flushPendingDebugLogs(immediate: true)
                    runTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    statusMessage = "Test cancelled."
                    isRunning = false
                    appendLog("[Cancelled]", debug: false)
                    flushDebugSummaries()
                    flushPendingDebugLogs(immediate: true)
                    runTask = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                    appendLog("[Error] \(error.localizedDescription)", debug: false)
                    flushDebugSummaries()
                    flushPendingDebugLogs(immediate: true)
                    runTask = nil
                }
            }
        }
    }

    private func cancelRunningTest() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        flushDebugSummaries()
        flushPendingDebugLogs(immediate: true)
    }

    @MainActor
    private func handleStreamUpdate(_ update: QueryStreamUpdate) {
        let appendedCount = update.metrics?.batchRowCount
            ?? (!update.appendedRows.isEmpty ? update.appendedRows.count : update.encodedRows.count)

        tracker.recordStreamUpdate(appendedRowCount: appendedCount, totalRowCount: update.totalRowCount)

        if let metrics = update.metrics {
            tracker.recordBackendMetrics(metrics)
            emitDebugSummaries(for: metrics)
            if metrics.fetchRowCount == 0 {
                flushDebugSummaries()
            }
        }
    }

    @MainActor
    private func emitDebugSummaries(for metrics: QueryStreamMetrics) {
        if let summaries = debugAggregator.record(metrics: metrics), logFilter == .debug {
            for summary in summaries {
                appendLog(summary, debug: true)
            }
        }
    }

    @MainActor
    private func flushDebugSummaries() {
        if let summaries = logFilter == .debug ? debugAggregator.flushRemaining() : nil {
            for summary in summaries {
                appendLog(summary, debug: true)
            }
        }
        if logFilter != .debug {
            debugAggregator.reset()
        }
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds < 60 ? [.second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? String(format: "%.2fs", seconds)
    }

    private var filteredLogs: [StreamingLogEntry] {
        switch logFilter {
        case .simple:
            return logs.filter { !$0.isDebug }
        case .debug:
            return logs
        }
    }

    private func appendLog(_ message: String, debug: Bool) {
        let entry = StreamingLogEntry(message: message, isDebug: debug)
        if !debug {
            logs.append(entry)
            trimLogsIfNeeded()
            return
        }

        guard logFilter == .debug else { return }
        pendingDebugLogs.append(entry)
        if pendingDebugLogs.count >= 20 {
            flushPendingDebugLogs()
        } else {
            scheduleDebugLogFlush()
        }
    }

    private func copyLogsToClipboard() {
        flushPendingDebugLogs(immediate: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let text = filteredLogs
            .map { "[\u{200E}\(formatter.string(from: $0.timestamp))] \($0.message)" }
            .joined(separator: "\n")
#if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
#elseif canImport(UIKit)
        UIPasteboard.general.string = text
#endif
    }

    private func scheduleDebugLogFlush() {
        guard debugFlushTask == nil else { return }
        debugFlushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            flushPendingDebugLogs()
        }
    }

    private func flushPendingDebugLogs(immediate: Bool = false) {
        if immediate {
            debugFlushTask?.cancel()
        }
        debugFlushTask = nil
        guard !pendingDebugLogs.isEmpty else { return }
        logs.append(contentsOf: pendingDebugLogs)
        pendingDebugLogs.removeAll(keepingCapacity: true)
        trimLogsIfNeeded()
    }

    private func trimLogsIfNeeded() {
        let overflow = logs.count - 600
        if overflow > 0 {
            logs.removeFirst(overflow)
        }
    }
}

private enum LogVisibility: String, CaseIterable, Identifiable {
    case simple
    case debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: return "Simple"
        case .debug: return "Debug"
        }
    }
}

private struct StreamingLogEntry: Identifiable {
    let id = UUID()
   let timestamp = Date()
   let message: String
   let isDebug: Bool
}

private struct DebugLogAggregator {
    private(set) var nextFetchIndex: Int = 1
    private var pendingMetrics: [QueryStreamMetrics] = []
    private var lastFlushTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    mutating func reset() {
        nextFetchIndex = 1
        pendingMetrics.removeAll(keepingCapacity: true)
        lastFlushTime = CFAbsoluteTimeGetCurrent()
    }

    mutating func record(metrics: QueryStreamMetrics) -> [String]? {
        guard metrics.batchRowCount > 0 || (metrics.fetchRowCount ?? 0) > 0 else {
            return nil
        }
        if let request = metrics.fetchRequestRowCount,
           let rows = metrics.fetchRowCount,
           request == 0,
           rows == 0 {
            return nil
        }
        pendingMetrics.append(metrics)
        let now = CFAbsoluteTimeGetCurrent()
        if pendingMetrics.count >= 4 || now - lastFlushTime >= 0.5 {
            return flush(currentTime: now)
        }
        return nil
    }

    mutating func flushRemaining() -> [String]? {
        guard !pendingMetrics.isEmpty else { return nil }
        return flush(currentTime: CFAbsoluteTimeGetCurrent())
    }

    private mutating func flush(currentTime: CFAbsoluteTime) -> [String] {
        let startIndex = nextFetchIndex
        nextFetchIndex += pendingMetrics.count
        let messages = pendingMetrics.enumerated().map { offset, metric -> String in
            let fetchNumber = startIndex + offset
            let requested = metric.fetchRequestRowCount ?? metric.batchRowCount
            let rows = metric.fetchRowCount ?? metric.batchRowCount
            let duration = metric.fetchDuration ?? metric.loopElapsed
            let wait = metric.fetchWait ?? max(duration - metric.decodeDuration, 0)
            let throughput = (duration > 0 && rows > 0) ? Double(rows) / duration : 0
            return String(
                format: "[Fetch #%d] requested=%d rows=%d wait=%.3fs decode=%.3fs loop=%.3fs rows/s=%.0f total=%d",
                fetchNumber,
                requested,
                rows,
                wait,
                metric.decodeDuration,
                duration,
                throughput,
                metric.cumulativeRowCount
            )
        }
        pendingMetrics.removeAll(keepingCapacity: true)
        lastFlushTime = currentTime
        return messages
    }
}

private func formatBytesBinary(_ bytes: Int) -> String {
    let units: [String] = ["B", "KB", "MB", "GB", "TB", "PB"]
    guard bytes > 0 else { return "0 B" }
    var value = Double(bytes)
    var index = 0
    while value >= 1024, index < units.count - 1 {
        value /= 1024
        index += 1
    }
    if index == 0 {
        return "\(bytes) B"
    }
    let rounded = (value * 100).rounded() / 100
    if rounded.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(rounded)) \(units[index])"
    }
    return "\(rounded) \(units[index])"
}

private struct StreamingReportSummary: View {
    let report: QueryPerformanceTracker.Report

    private var timings: [(label: String, value: String)] {
        var items: [(String, String)] = []
        if let dispatch = report.timings.startToDispatch {
            items.append(("Dispatch", Self.format(dispatch)))
        }
        if let first = report.timings.startToFirstUpdate {
            items.append(("First batch", Self.format(first)))
        }
        if let initial = report.timings.startToInitialBatch {
            items.append(("Initial target", Self.format(initial)))
        }
        if let finish = report.timings.startToFinish {
            items.append(("Finish", Self.format(finish)))
        }
        return items
    }

    private var throughput: String {
        guard let total = report.timings.startToFinish, total > 0 else {
            return "—"
        }
        let rowsPerSecond = Double(report.totalRows) / total
        return String(format: "%.0f rows/s", rowsPerSecond)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading),
                GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading),
                GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading)
            ], alignment: .leading, spacing: 12) {
                metric("Total rows", value: "\(report.totalRows)")
                metric("Batches", value: "\(report.batchCount)")
                metric("Largest batch", value: "\(report.largestBatchSize)")
                metric("First batch", value: report.firstBatchSize.map { "\($0)" } ?? "—")
                metric("Throughput", value: throughput)
                metric("Estimated memory", value: report.estimatedMemoryBytes.map(formatBytesBinary) ?? "—")
            }

            if !timings.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Timings")
                        .font(.subheadline.bold())
                    ForEach(timings, id: \.label) { item in
                        HStack {
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text(item.value)
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }

            if let sample = report.backendSamples.last {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest Backend Sample")
                        .font(.subheadline.bold())
                    HStack(spacing: 18) {
                        metric("Rows in batch", value: "\(sample.batchRowCount)")
                        metric("Total rows", value: "\(sample.cumulativeRowCount)")
                        metric("Loop", value: Self.format(sample.loopElapsed))
                        metric("Decode", value: Self.format(sample.decodeDuration))
                        metric("Network wait", value: Self.format(sample.networkWaitDuration))
                    }
                }
            }
        }
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
    }

    private static func format(_ time: TimeInterval) -> String {
        let milliseconds = time * 1000
        if milliseconds < 1000 {
            return String(format: "%.0f ms", milliseconds)
        }
        return String(format: "%.2f s", time)
    }

}

private final class PreviewDatabaseSession: DatabaseSession, @unchecked Sendable {
    func close() async {}

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        QueryResultSet(columns: [])
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        []
    }

    func listDatabases() async throws -> [String] {
        ["analytics"]
    }

    func listSchemas() async throws -> [String] {
        ["public"]
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        []
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        "-- preview definition"
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        0
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        TableStructureDetails()
    }
}
