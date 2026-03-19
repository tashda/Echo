import SwiftUI

struct PostgresMaintenanceHealthView: View {
    var viewModel: MaintenanceViewModel

    var body: some View {
        if let health = viewModel.healthStats {
            healthContent(health)
        } else if viewModel.isLoadingHealth {
            VStack(spacing: SpacingTokens.md) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading health data\u{2026}")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStatePlaceholder(
                icon: "heart",
                title: "Health Unavailable",
                subtitle: "Could not load database health statistics"
            )
        }
    }

    private func healthContent(_ health: PostgresMaintenanceHealth) -> some View {
        Form {
            Section("Database") {
                PropertyRow(title: "Database") {
                    Text(health.databaseName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                PropertyRow(title: "Size") {
                    Text(ByteCountFormatter.string(fromByteCount: health.databaseSizeBytes, countStyle: .binary))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                PropertyRow(title: "Tables") {
                    Text("\(health.tableCount)")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                PropertyRow(title: "Indexes") {
                    Text("\(health.indexCount)")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Section("Performance") {
                PropertyRow(
                    title: "Cache Hit Ratio",
                    info: cacheHitInfo(health.cacheHitRatio)
                ) {
                    if let ratio = health.cacheHitRatio {
                        Text(String(format: "%.2f%%", ratio))
                            .foregroundStyle(cacheHitColor(ratio))
                    } else {
                        Text("\u{2014}")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }

                PropertyRow(
                    title: "Connections",
                    info: connectionInfo(health)
                ) {
                    HStack(spacing: SpacingTokens.xs) {
                        Text("\(health.activeConnections) / \(health.maxConnections)")
                            .foregroundStyle(connectionColor(health))
                        Text(String(format: "(%.0f%%)", health.connectionUsagePercent))
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }

                PropertyRow(
                    title: "Dead Tuple Backlog",
                    info: deadTupleInfo(health.deadTupleBacklog)
                ) {
                    Text(formatCount(health.deadTupleBacklog))
                        .foregroundStyle(health.deadTupleBacklog > 100_000 ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
                }

                if let oldestTx = health.oldestTransactionSeconds {
                    PropertyRow(
                        title: "Oldest Transaction",
                        info: oldestTxInfo(oldestTx)
                    ) {
                        Text(formatDuration(oldestTx))
                            .foregroundStyle(oldestTx > 3600 ? ColorTokens.Status.error : oldestTx > 300 ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
                    }
                }
            }

            Section("Transaction ID Wraparound") {
                PropertyRow(
                    title: "Transaction ID Age",
                    info: txidInfo(health)
                ) {
                    HStack(spacing: SpacingTokens.xs) {
                        Text(formatXidAge(health.transactionIdAge))
                            .foregroundStyle(txidColor(health.txidSeverity))
                        Text(String(format: "(%.1f%%)", health.txidAgePercent))
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }

                txidGauge(health)
            }

            if let bg = health.bgwriterStats {
                Section("Background Writer") {
                    PropertyRow(
                        title: "Checkpoints (timed / requested)",
                        info: checkpointInfo(bg)
                    ) {
                        Text("\(bg.checkpointsTimed) / \(bg.checkpointsRequested)")
                            .foregroundStyle(bg.checkpointsRequested > bg.checkpointsTimed ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
                    }

                    PropertyRow(
                        title: "Buffers Written",
                        info: buffersInfo(bg)
                    ) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Checkpoint: \(formatCount(bg.buffersCheckpoint))")
                            Text("Background: \(formatCount(bg.buffersClean))")
                            Text("Backend: \(formatCount(bg.buffersBackend))")
                                .foregroundStyle(bg.buffersBackend > bg.buffersCheckpoint ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
                        }
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - TXID Gauge

    private func txidGauge(_ health: PostgresMaintenanceHealth) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            GeometryReader { geo in
                let fraction = min(health.txidAgePercent / 100, 1.0)
                let barWidth = geo.size.width
                let position = barWidth * fraction

                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.Background.tertiary)
                        .frame(height: 6)

                    // Fill bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(txidColor(health.txidSeverity))
                        .frame(width: max(2, position), height: 6)

                    // Marker pin — always visible even at tiny values
                    Circle()
                        .fill(txidColor(health.txidSeverity))
                        .frame(width: 12, height: 12)
                        .shadow(color: txidColor(health.txidSeverity).opacity(0.4), radius: 3)
                        .offset(x: max(0, min(position - 6, barWidth - 12)))
                }
            }
            .frame(height: 12)

            // Scale labels
            HStack {
                Text("0")
                Spacer()
                Text("500M")
                Spacer()
                Text("1B")
                Spacer()
                Text("1.5B")
                Spacer()
                Text("2B")
            }
            .font(TypographyTokens.label)
            .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Contextual Info Strings

    private func cacheHitInfo(_ ratio: Double?) -> String {
        let base = "Percentage of data reads served from shared buffers."
        guard let ratio else { return base }
        if ratio >= 99 { return "\(base) Current ratio is excellent." }
        if ratio >= 95 { return "\(base)\n\nAction: Consider increasing shared_buffers in postgresql.conf. Current ratio suggests some reads are hitting disk." }
        return "\(base)\n\nAction: Increase shared_buffers significantly. Current ratio indicates heavy disk I/O. Also check for sequential scans on large tables (add missing indexes)."
    }

    private func connectionInfo(_ health: PostgresMaintenanceHealth) -> String {
        let base = "Active connections vs max_connections."
        if health.connectionUsagePercent > 80 {
            return "\(base)\n\nAction: Connection usage is critically high. Consider using a connection pooler (PgBouncer) or increasing max_connections. Investigate idle connections that should be closed."
        }
        if health.connectionUsagePercent > 60 {
            return "\(base)\n\nAction: Connection usage is elevated. Monitor for leaking connections. Consider a connection pooler if usage continues to grow."
        }
        return "\(base) Current usage is healthy."
    }

    private func deadTupleInfo(_ backlog: Int64) -> String {
        let base = "Total dead tuples across all tables."
        if backlog > 1_000_000 {
            return "\(base)\n\nAction: Autovacuum is significantly behind. Check for long-running transactions blocking vacuum (Oldest Transaction above). Consider running VACUUM manually on the largest tables, or tuning autovacuum_vacuum_cost_delay and autovacuum_vacuum_scale_factor."
        }
        if backlog > 100_000 {
            return "\(base)\n\nAction: Autovacuum may be falling behind. Check autovacuum settings and look for tables with high dead tuple counts in the Tables tab."
        }
        return "\(base) Current backlog is manageable."
    }

    private func oldestTxInfo(_ seconds: Int64) -> String {
        let base = "Long-running transactions prevent autovacuum from reclaiming dead tuples."
        if seconds > 3600 {
            return "\(base)\n\nAction: A transaction has been open for over an hour. This blocks vacuum across all tables. Identify and terminate the idle session using pg_terminate_backend(), or investigate why the application is holding a transaction open."
        }
        if seconds > 300 {
            return "\(base)\n\nAction: A transaction has been running for several minutes. Monitor it — if idle, consider terminating it to unblock autovacuum."
        }
        return "\(base) No concerning long-running transactions."
    }

    private func txidInfo(_ health: PostgresMaintenanceHealth) -> String {
        let base = "PostgreSQL must vacuum tables before their transaction ID age reaches 2 billion. At that point the database shuts down to prevent data corruption."
        switch health.txidSeverity {
        case .critical:
            return "\(base)\n\nAction: CRITICAL — Transaction ID age is dangerously high. Run VACUUM FREEZE immediately on tables with the highest age (check the Age column in the Tables tab). If autovacuum is blocked by long transactions, terminate them first."
        case .warning:
            return "\(base)\n\nAction: Transaction ID age is elevated. Ensure autovacuum is running and not blocked. Check tables with high age in the Tables tab and consider running VACUUM FREEZE on them."
        case .healthy:
            return "\(base) Current age is healthy."
        }
    }

    private func checkpointInfo(_ bg: PostgresMaintenanceHealth.BGWriterStats) -> String {
        let base = "Timed checkpoints run on schedule. Requested checkpoints are forced by heavy write activity."
        if bg.checkpointsRequested > bg.checkpointsTimed {
            return "\(base)\n\nAction: More checkpoints are being forced than scheduled. Increase checkpoint_completion_target (to 0.9) and max_wal_size to allow longer intervals between checkpoints."
        }
        return "\(base) Current ratio is normal."
    }

    private func buffersInfo(_ bg: PostgresMaintenanceHealth.BGWriterStats) -> String {
        let base = "Buffers written by the checkpointer, background writer, and client backends."
        if bg.buffersBackend > bg.buffersCheckpoint {
            return "\(base)\n\nAction: Backends are writing more buffers than the checkpointer, indicating the background writer can't keep up. Increase bgwriter_lru_maxpages and bgwriter_lru_multiplier to write dirty pages more aggressively."
        }
        return "\(base) Buffer write distribution is healthy."
    }

    // MARK: - Helpers

    private func cacheHitColor(_ ratio: Double) -> Color {
        if ratio >= 99 { return ColorTokens.Status.success }
        if ratio >= 95 { return ColorTokens.Status.warning }
        return ColorTokens.Status.error
    }

    private func connectionColor(_ health: PostgresMaintenanceHealth) -> Color {
        if health.connectionUsagePercent > 80 { return ColorTokens.Status.error }
        if health.connectionUsagePercent > 60 { return ColorTokens.Status.warning }
        return ColorTokens.Text.secondary
    }

    private func txidColor(_ severity: PostgresMaintenanceHealth.TxidSeverity) -> Color {
        switch severity {
        case .critical: return ColorTokens.Status.error
        case .warning: return ColorTokens.Status.warning
        case .healthy: return ColorTokens.Status.success
        }
    }

    private func formatCount(_ count: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func formatXidAge(_ age: Int64) -> String {
        if age >= 1_000_000_000 { return String(format: "%.2fB", Double(age) / 1_000_000_000) }
        if age >= 1_000_000 { return String(format: "%.0fM", Double(age) / 1_000_000) }
        return "\(age)"
    }

    private func formatDuration(_ seconds: Int64) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }
}
