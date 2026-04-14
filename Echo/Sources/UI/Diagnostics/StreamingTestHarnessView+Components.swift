import SwiftUI

extension StreamingTestHarnessView {
    var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Streaming Test Harness")
                .font(TypographyTokens.title.weight(.bold))
            Text("Execute diagnostic queries without the results grid to inspect streaming performance, batching, and driver throughput.")
                .font(TypographyTokens.callout)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.md2)
    }

    var content: some View {
        HStack(spacing: SpacingTokens.lg) {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                sessionPicker
                sqlEditor
                controlButtons
                statusIndicators
                Spacer()
            }
            .frame(width: 320)

            Divider()

            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                reportSection
                Divider()
                logSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(SpacingTokens.lg)
    }

    var sessionPicker: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text("Connection")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
            if availableSessions.isEmpty {
                Text("No active connections.\nOpen a connection first.")
                    .font(TypographyTokens.footnote)
                    .foregroundStyle(ColorTokens.Text.secondary)
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
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text("SQL")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
            TextEditor(text: $sqlInput)
                .font(TypographyTokens.monospaced)
                .lineSpacing(4)
                .disableAutocorrection(true)
                .frame(minHeight: 140, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(ColorTokens.Text.secondary.opacity(0.12), lineWidth: 1)
                )
        }
    }

    var controlButtons: some View {
        HStack(spacing: SpacingTokens.sm) {
            if !isRunning && selectedSession != nil && !sqlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    runStreamingTest()
                } label: {
                    Label("Run Test", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xxs2)
                }
                .buttonStyle(.bordered)
            } else {
                Button {} label: {
                    Label("Run Test", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xxs2)
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }

            Button {
                cancelRunningTest()
            } label: {
                Label("Cancel", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(ColorTokens.Status.warning)
            .disabled(!isRunning)
        }
    }

    var statusIndicators: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if isRunning {
                HStack(spacing: SpacingTokens.xs) {
                    ProgressView()
                    Text("Running query…")
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            if let message = statusMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Status.success)
                    .font(TypographyTokens.footnote)
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
                    .font(TypographyTokens.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var reportSection: some View {
        Group {
            if let report {
                StreamingReportSummary(report: report)
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Results")
                        .font(TypographyTokens.headline)
                    Text("Run a test to view timings and batch metrics.")
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    var logSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("Stream Log")
                    .font(TypographyTokens.headline)
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
                LazyVStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    ForEach(filteredLogs) { entry in
                        HStack(alignment: .top, spacing: SpacingTokens.sm) {
                            Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                                .font(TypographyTokens.caption2.monospacedDigit())
                                .foregroundStyle(ColorTokens.Text.secondary)
                            Text(entry.message)
                                .font(TypographyTokens.caption.monospaced())
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
                    .strokeBorder(ColorTokens.Text.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
