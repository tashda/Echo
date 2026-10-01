import SwiftUI
import Charts

struct SparklineMetric {
    let label: String
    let unit: String
    let color: Color
    let maxValue: Double?
    let data: [ActivityMonitorViewModel.GraphPoint]
}

/// TT3 (design board, 2026-09-30): the monitor's key figures as tiles, each on its own card,
/// with the current value large and a sparkline of the recent history.
struct ActivityMonitorSparklineStrip: View {
    let metrics: [SparklineMetric]

    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        HStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                ActivityMetricTile(metric: metric)
                    .workspaceCard()
            }
        }
        .frame(height: LayoutTokens.ToolTab.tileHeight)
    }
}

private struct ActivityMetricTile: View {
    let metric: SparklineMetric

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text(metric.label)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            valueText
            sparkline
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var valueText: some View {
        if let value = metric.data.last?.value {
            Text("\(Text("\(Int(value))").font(TypographyTokens.statNumber))\(Text(metric.unit).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary))")
                .monospacedDigit()
                .foregroundStyle(ColorTokens.Text.primary)
        } else {
            Text("\u{2014}")
                .font(TypographyTokens.statNumber)
                .foregroundStyle(ColorTokens.Text.quaternary)
        }
    }

    @ViewBuilder
    private var sparkline: some View {
        if metric.data.count >= 2 {
            let top = metric.maxValue ?? max(1, (metric.data.map(\.value).max() ?? 0) * 1.2)
            Chart(metric.data) { point in
                AreaMark(x: .value("Time", point.timestamp), y: .value("Value", point.value))
                    .foregroundStyle(metric.color.opacity(0.14))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", point.timestamp), y: .value("Value", point.value))
                    .foregroundStyle(metric.color.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...top)
            .frame(height: LayoutTokens.ToolTab.tileSparklineHeight)
        } else {
            Spacer(minLength: LayoutTokens.ToolTab.tileSparklineHeight)
        }
    }
}
