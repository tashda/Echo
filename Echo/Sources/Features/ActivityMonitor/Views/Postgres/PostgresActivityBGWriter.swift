import SwiftUI
import PostgresKit

struct PostgresActivityBGWriter: View {
    let connectionID: UUID
    @Environment(EnvironmentState.self) private var environmentState

    @State private var stats: PostgresBGWriterStats?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let stats {
                statsForm(stats)
            } else if isLoading {
                ActivitySectionLoadingView(title: "Loading Background Writer Stats", subtitle: "Fetching from pg_stat_bgwriter\u{2026}")
            } else {
                ContentUnavailableView {
                    Label("No Data", systemImage: "doc.plaintext")
                } description: {
                    Text("Could not load background writer statistics.")
                }
            }
        }
        .task { await loadStats() }
    }

    private func statsForm(_ stats: PostgresBGWriterStats) -> some View {
        Form {
            Section("Checkpoints") {
                PropertyRow(title: "Timed Checkpoints") {
                    Text(formatNumber(stats.checkpointsTimed))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Requested Checkpoints") {
                    Text(formatNumber(stats.checkpointsReq))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(stats.checkpointsReq > stats.checkpointsTimed ? ColorTokens.Status.warning : ColorTokens.Text.primary)
                }
                PropertyRow(title: "Checkpoint Write Time") {
                    Text(formatMilliseconds(stats.checkpointWriteTime))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Checkpoint Sync Time") {
                    Text(formatMilliseconds(stats.checkpointSyncTime))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Section("Buffers") {
                PropertyRow(title: "Checkpoint Buffers") {
                    Text(formatNumber(stats.buffersCheckpoint))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Clean Buffers") {
                    Text(formatNumber(stats.buffersClean))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Max Written Clean") {
                    Text(formatNumber(stats.maxwrittenClean))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(stats.maxwrittenClean > 0 ? ColorTokens.Status.warning : ColorTokens.Text.primary)
                }
                PropertyRow(title: "Backend Buffers") {
                    Text(formatNumber(stats.buffersBackend))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Backend Fsync") {
                    Text(formatNumber(stats.buffersBackendFsync))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(stats.buffersBackendFsync > 0 ? ColorTokens.Status.error : ColorTokens.Text.primary)
                }
                PropertyRow(title: "Allocated Buffers") {
                    Text(formatNumber(stats.buffersAlloc))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .topTrailing) {
            Button { Task { await loadStats() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .padding(SpacingTokens.md)
        }
    }

    private func formatNumber(_ value: Int64) -> String {
        if value >= 1_000_000 { return String(format: "%.2fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private func formatMilliseconds(_ value: Double) -> String {
        if value >= 60_000 { return String(format: "%.1f min", value / 60_000) }
        if value >= 1_000 { return String(format: "%.1f s", value / 1_000) }
        return String(format: "%.0f ms", value)
    }

    private func loadStats() async {
        guard let session = environmentState.sessionGroup.sessionForConnection(connectionID),
              let pg = session.session as? PostgresSession else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            stats = try await pg.client.introspection.fetchBGWriterStats()
        } catch {
            stats = nil
        }
    }
}
