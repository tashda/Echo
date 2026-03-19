import SwiftUI
import Charts

struct SparklineMetric {
    let label: String
    let unit: String
    let color: Color
    let maxValue: Double?
    let data: [ActivityMonitorViewModel.GraphPoint]
}

struct ActivityMonitorSparklineStrip: View {
    let metrics: [SparklineMetric]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                if index > 0 {
                    Divider().frame(height: 50)
                }
                SparklineCell(metric: metric)
            }
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.horizontal, SpacingTokens.sm)
    }
}

private struct SparklineCell: View {
    let metric: SparklineMetric

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(metric.label)
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)

                if let value = metric.data.last?.value {
                    Text("\(Int(value))\(metric.unit)")
                        .font(TypographyTokens.detail.weight(.medium).monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.primary)
                } else {
                    Text("\u{2014}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }
            }
            .frame(minWidth: 60, alignment: .leading)

            if metric.data.count >= 2 {
                Chart(metric.data) {
                    LineMark(
                        x: .value("Time", $0.timestamp),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(metric.color.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(metric.maxValue ?? max(1, (metric.data.map(\.value).max() ?? 0) * 1.2)))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SpacingTokens.xs)
    }
}
