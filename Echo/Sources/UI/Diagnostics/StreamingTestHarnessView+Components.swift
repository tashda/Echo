import SwiftUI

extension StreamingTestHarnessView {
    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streaming Test Harness")
                .font(.title2.bold())
            Text("Execute diagnostic queries without the results grid to inspect streaming performance, batching, and driver throughput.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.md2)
    }

    var content: some View {
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
        .padding(SpacingTokens.lg)
    }

    var sessionPicker: some View {
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

    var sqlEditor: some View {
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

    var controlButtons: some View {
        HStack(spacing: 12) {
            Button {
                runStreamingTest()
            } label: {
                Label("Run Test", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, SpacingTokens.xxs2)
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

    var statusIndicators: some View {
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

    var reportSection: some View {
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

    var logSection: some View {
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
                .padding(SpacingTokens.sm)
            }
            .frame(minHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ColorTokens.Background.secondary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.6 : 0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
