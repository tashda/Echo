import SwiftUI
import Charts

/// A single dashboard chart card showing a time-series metric with line + area fill.
/// Reusable across both Postgres and MSSQL activity monitors.
struct DashboardChartView: View {
    let title: String
    let unit: String
    let color: Color
    let data: [ActivityMonitorViewModel.GraphPoint]
    var maxValue: Double?
    var showAsPercentage: Bool = false

    private var currentValue: String {
        guard let last = data.last else { return "\u{2014}" }
        if showAsPercentage {
            return String(format: "%.1f%%", last.value)
        }
        return "\(Int(last.value))\(unit)"
    }

    private var yDomain: ClosedRange<Double> {
        let ceiling = maxValue ?? max(1, (data.map(\.value).max() ?? 0) * 1.2)
        return 0...ceiling
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            chartHeader
            chartContent
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var chartHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
            Text(currentValue)
                .font(TypographyTokens.prominent.weight(.semibold).monospacedDigit())
                .foregroundStyle(ColorTokens.Text.primary)
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if !data.isEmpty {
            Chart(data) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color.opacity(0.9))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(ColorTokens.Text.quaternary)
                    AxisValueLabel(format: .dateTime.hour().minute().second())
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(ColorTokens.Text.quaternary)
                    AxisValueLabel()
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .frame(minHeight: 120)
            .animation(.linear(duration: 0.3), value: data.count)
        } else {
            ContentUnavailableView {
                Label("Collecting Data", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Waiting for metrics\u{2026}")
            }
            .frame(minHeight: 120)
        }
    }
}
