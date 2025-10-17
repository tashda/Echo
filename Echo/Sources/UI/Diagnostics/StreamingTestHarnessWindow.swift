import SwiftUI

struct StreamingTestHarnessWindow: Scene {
    static let sceneID = "streaming-test-harness"

    var body: some Scene {
        Window("Streaming Test Harness", id: Self.sceneID) {
            StreamingTestHarnessView()
                .environmentObject(AppCoordinator.shared.appModel)
                .environmentObject(AppCoordinator.shared.themeManager)
        }
        .defaultSize(width: 840, height: 620)
    }
}

private struct StreamingTestHarnessView: View {
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
        .background(themeManager.windowBackground)
        .onAppear {
            if selectedSessionID == nil {
                selectedSessionID = availableSessions.first?.id
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
                Button("Clear") {
                    logs.removeAll()
                }
                .disabled(logs.isEmpty || isRunning)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(logs) { entry in
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

        let initialBatchTarget = max(100, appModel.globalSettings.resultsInitialRowLimit)
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
                    runTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    statusMessage = "Test cancelled."
                    isRunning = false
                    runTask = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                    runTask = nil
                }
            }
        }
    }

    private func cancelRunningTest() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }

    @MainActor
    private func handleStreamUpdate(_ update: QueryStreamUpdate) {
        let appendedCount = update.metrics?.batchRowCount
            ?? (!update.appendedRows.isEmpty ? update.appendedRows.count : update.encodedRows.count)

        tracker.recordStreamUpdate(appendedRowCount: appendedCount, totalRowCount: update.totalRowCount)
        if appendedCount > 0 {
            logs.append(.init(message: "[Batch] rows=\(appendedCount) total=\(update.totalRowCount)"))
        }

        if let metrics = update.metrics {
            tracker.recordBackendMetrics(metrics)
            let message = String(
                format: "[Metrics] batch=%d total=%d loop=%.3fs decode=%.3fs wait=%.3fs",
                metrics.batchRowCount,
                metrics.cumulativeRowCount,
                metrics.loopElapsed,
                metrics.decodeDuration,
                metrics.networkWaitEstimate
            )
            logs.append(.init(message: message))
        } else if appendedCount == 0 {
            logs.append(.init(message: "[Update] total=\(update.totalRowCount) (no metrics)"))
        }
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds < 60 ? [.second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? String(format: "%.2fs", seconds)
    }
}

private struct StreamingLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
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
                metric("Estimated memory", value: report.estimatedMemoryBytes.map(Self.formatBytes) ?? "—")
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

    private static func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }
}
