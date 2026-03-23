import SwiftUI

struct PostgresMaintenanceHealthView: View {
    var viewModel: MaintenanceViewModel

    var body: some View {
        if let health = viewModel.healthStats {
            healthContent(health)
        } else if viewModel.isLoadingHealth {
            TabInitializingPlaceholder(
                icon: "heart",
                title: "Loading Health Data",
                subtitle: "Analyzing database health statistics\u{2026}"
            )
        } else {
            ContentUnavailableView {
                Label("Health Unavailable", systemImage: "heart")
            } description: {
                Text("Could not load database health statistics.")
            }
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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.Background.tertiary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(txidColor(health.txidSeverity))
                        .frame(width: max(2, position), height: 6)

                    Circle()
                        .fill(txidColor(health.txidSeverity))
                        .frame(width: 12, height: 12)
                        .shadow(color: txidColor(health.txidSeverity).opacity(0.4), radius: 3)
                        .offset(x: max(0, min(position - 6, barWidth - 12)))
                }
            }
            .frame(height: 12)

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
}
