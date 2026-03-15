import SwiftUI
import Charts

/// A modern container for dashboard sections
struct SectionContainer<Content: View>: View {
    let title: String
    let icon: String
    let info: String?
    let content: () -> Content

    init(title: String, icon: String, info: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.info = info
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: icon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.accent)
                Text(title.uppercased())
                    .font(TypographyTokens.detail.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .kerning(0.5)

                if let info = info {
                   SectionInfoButton(info: info)
                }
                }
                .padding(.leading, SpacingTokens.xxxs)
            content()
                .background(ColorTokens.Background.secondary.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTokens.Text.primary.opacity(0.05), lineWidth: 1)
                )
        }
    }
}

struct OverviewGraphsView: View {
    var viewModel: ActivityMonitorViewModel

    var body: some View {
        Grid(horizontalSpacing: SpacingTokens.lg, verticalSpacing: SpacingTokens.lg) {
            GridRow {
                GraphCell(
                    title: "% Processor Time",
                    data: viewModel.cpuHistory,
                    unit: "%",
                    maxValue: 100,
                    color: .blue,
                    info: "Estimated CPU utilization based on active (non-idle) database sessions relative to server capacity."
                )
                GraphCell(
                    title: "Waiting Tasks",
                    data: viewModel.waitingTasksHistory,
                    unit: "",
                    maxValue: nil,
                    color: .orange,
                    info: "The number of tasks currently blocked waiting for a resource (lock, memory, disk, etc)."
                )
            }
            GridRow {
                GraphCell(
                    title: "Database I/O",
                    data: viewModel.ioHistory,
                    unit: " MB/s",
                    maxValue: nil,
                    color: .purple,
                    info: "Current volume of data being read from or written to the data files per second."
                )
                GraphCell(
                    title: "Throughput",
                    data: viewModel.throughputHistory,
                    unit: " /s",
                    maxValue: nil,
                    color: .green,
                    info: "Rate of work being completed (Batch Requests/sec for MSSQL, Transactions/sec for Postgres)."
                )
            }
        }
        .padding(SpacingTokens.md)
    }
}

struct GraphCell: View {
    let title: String
    let data: [ActivityMonitorViewModel.GraphPoint]
    let unit: String
    let maxValue: Double?
    let color: Color
    let info: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text(title)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)

                SectionInfoButton(info: info)

                Spacer()
                if let last = data.last?.value {
                    Text("\(Int(last))\(unit)")
                        .font(TypographyTokens.standard.weight(.bold))
                        .foregroundStyle(color)
                }
            }

            Chart(data) {
                AreaMark(
                    x: .value("Time", $0.timestamp),
                    y: .value("Value", $0.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", $0.timestamp),
                    y: .value("Value", $0.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(dash: [2, 4]))
                        .foregroundStyle(ColorTokens.Text.primary.opacity(0.1))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue))")
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...(maxValue ?? max(10, data.map { $0.value }.max() ?? 0) * 1.2))
            .frame(height: 80)
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Text.primary.opacity(0.03))
        .cornerRadius(6)
    }
}
