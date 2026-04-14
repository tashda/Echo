import SwiftUI
import PostgresKit

struct PostgresActivityWAL: View {
    let connectionID: UUID
    var activityEngine: ActivityEngine?
    @Environment(EnvironmentState.self) private var environmentState

    @State private var stats: PostgresWALStats?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let stats {
                statsForm(stats)
            } else if isLoading {
                ActivitySectionLoadingView(title: "Loading WAL Statistics", subtitle: "Fetching from pg_stat_wal\u{2026}")
            } else {
                ContentUnavailableView {
                    Label("WAL Statistics Unavailable", systemImage: "doc.plaintext")
                } description: {
                    Text("Requires PostgreSQL 14 or later.")
                }
            }
        }
        .task { await loadStats() }
    }

    private func statsForm(_ stats: PostgresWALStats) -> some View {
        Form {
            Section("WAL Activity") {
                PropertyRow(title: "WAL Records") {
                    Text(formatLargeNumber(stats.walRecords))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Full Page Images") {
                    Text(formatLargeNumber(stats.walFPI))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "WAL Bytes") {
                    Text(formatBytes(stats.walBytes))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Buffers Full") {
                    Text(formatLargeNumber(stats.walBuffersFull))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(stats.walBuffersFull > 0 ? ColorTokens.Status.warning : ColorTokens.Text.primary)
                }
            }

            Section("Write / Sync") {
                PropertyRow(title: "Write Count") {
                    Text(formatLargeNumber(stats.walWrite))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Sync Count") {
                    Text(formatLargeNumber(stats.walSync))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.primary)
                }
                PropertyRow(title: "Write Time") {
                    Text(formatMilliseconds(stats.walWriteTime))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Sync Time") {
                    Text(formatMilliseconds(stats.walSyncTime))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            if let reset = stats.statsReset {
                Section("Reset") {
                    PropertyRow(title: "Stats Reset") {
                        Text(reset)
                            .font(TypographyTokens.Table.date)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
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

    private func formatLargeNumber(_ value: Int64) -> String {
        if value >= 1_000_000_000 { return String(format: "%.2fB", Double(value) / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.2fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private func formatBytes(_ value: Int64) -> String {
        if value >= 1_073_741_824 { return String(format: "%.2f GB", Double(value) / 1_073_741_824) }
        if value >= 1_048_576 { return String(format: "%.2f MB", Double(value) / 1_048_576) }
        if value >= 1_024 { return String(format: "%.1f KB", Double(value) / 1_024) }
        return "\(value) B"
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
        let handle = activityEngine?.begin("Loading WAL stats", connectionSessionID: connectionID)
        defer { isLoading = false }
        do {
            stats = try await pg.client.metadata.fetchWALStats()
            handle?.succeed()
        } catch {
            stats = nil
            handle?.fail(error.localizedDescription)
        }
    }
}
