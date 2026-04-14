import SwiftUI

struct MySQLActivityOverviewSection: View {
    let overview: MySQLActivityOverview

    var body: some View {
        SectionContainer(
            title: "Server Overview",
            icon: "gauge.with.dots.needle.33percent",
            info: "Live metrics sourced from MySQL status and server variable views."
        ) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: SpacingTokens.sm
            ) {
                metric(title: "Uptime", value: formatDuration(seconds: overview.uptimeSeconds))
                metric(title: "Connections", value: formatConnections(overview))
                metric(title: "Slow Queries", value: formatInteger(overview.slowQueries))
                metric(title: "Open Tables", value: formatTableCache(overview))
                metric(title: "Incoming", value: formatRateInKB(overview.bytesReceivedPerSecond))
                metric(title: "Outgoing", value: formatRateInKB(overview.bytesSentPerSecond))
                metric(title: "InnoDB Reads", value: formatRate(overview.innodbReadsPerSecond))
                metric(title: "InnoDB Writes", value: formatRate(overview.innodbWritesPerSecond))
            }
            .padding(SpacingTokens.md)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text(title)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(value)
                .font(TypographyTokens.prominent.weight(.semibold).monospacedDigit())
                .foregroundStyle(ColorTokens.Text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDuration(seconds: Int?) -> String {
        guard let seconds else { return "\u{2014}" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func formatConnections(_ overview: MySQLActivityOverview) -> String {
        if let maxConnections = overview.maxConnections {
            return "\(overview.currentConnections) / \(maxConnections)"
        }
        return "\(overview.currentConnections)"
    }

    private func formatTableCache(_ overview: MySQLActivityOverview) -> String {
        guard let openTables = overview.openTables else { return "\u{2014}" }
        if let tableOpenCache = overview.tableOpenCache {
            return "\(openTables) / \(tableOpenCache)"
        }
        return "\(openTables)"
    }

    private func formatInteger(_ value: Int?) -> String {
        guard let value else { return "\u{2014}" }
        return "\(value)"
    }

    private func formatRate(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        return String(format: "%.1f/s", value)
    }

    private func formatRateInKB(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else { return "\u{2014}" }
        return String(format: "%.1f KB/s", bytesPerSecond / 1024)
    }
}
