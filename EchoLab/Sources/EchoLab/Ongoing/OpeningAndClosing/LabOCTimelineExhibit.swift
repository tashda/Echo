import SwiftUI

/// The timing of each moment as bars on a clock, Echo today in grey above the proposal. It reads the
/// same table the stage runs on (LabOCTimings), so what it draws is what moves.
struct LabOCTimelineExhibit: View {
    let look: LabOCLook

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            moment("Launch", today: LabOCBars.launch(.today), proposal: LabOCBars.launch(look))
            moment("Connect", today: LabOCBars.connect(.today), proposal: LabOCBars.connect(look))
            moment("Close the last tab", today: LabOCBars.close(.today), proposal: LabOCBars.close(look))
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    private func moment(_ title: String, today: [LabOCBar], proposal: [LabOCBar]) -> some View {
        let end = max((today + proposal).map { $0.start + $0.duration }.max() ?? 1, 1)
        let axis = (end * 4).rounded(.up) / 4
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(title).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                block("Today", bars: today, axis: axis, muted: true)
                block("Proposal", bars: proposal, axis: axis, muted: false)
                clock(axis: axis)
            }
            .padding(SpacingTokens.xs)
            .workspaceCard()
        }
    }

    private func block(_ name: String, bars: [LabOCBar], axis: Double, muted: Bool) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Text(name).font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: LabOCTimelineLayout.nameWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                if bars.isEmpty {
                    Text(muted ? "Nothing animates; it all appears at once" : "Nothing animates")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(height: LabOCTimelineLayout.rowHeight)
                }
                ForEach(bars) { bar in row(bar, axis: axis, muted: muted) }
            }
        }
    }

    private func row(_ bar: LabOCBar, axis: Double, muted: Bool) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let x = width * bar.start / axis
            let barWidth = max(width * bar.duration / axis, 3)
            ZStack(alignment: .leading) {
                Capsule().fill(muted ? ColorTokens.Text.tertiary.opacity(0.45) : bar.role.color.opacity(0.85))
                    .frame(width: barWidth, height: LabOCTimelineLayout.barHeight)
                    .offset(x: x)
                // A bar late on the clock keeps its label on its left, so it never runs off the card.
                let labelOnLeft = x + barWidth > width * 0.55
                Text("\(bar.row) · \(bar.label)")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .frame(width: labelOnLeft ? max(x - SpacingTokens.xxs, 0) : nil, alignment: labelOnLeft ? .trailing : .leading)
                    .fixedSize(horizontal: !labelOnLeft, vertical: false)
                    .offset(x: labelOnLeft ? 0 : x + barWidth + SpacingTokens.xxs)
            }
            .frame(height: LabOCTimelineLayout.rowHeight)
        }
        .frame(height: LabOCTimelineLayout.rowHeight)
    }

    private func clock(axis: Double) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Color.clear.frame(width: LabOCTimelineLayout.nameWidth, height: 1)
            GeometryReader { proxy in
                let ticks = Array(stride(from: 0.0, through: axis, by: 0.25))
                ZStack(alignment: .topLeading) {
                    ForEach(ticks, id: \.self) { tick in
                        let isWhole = tick.truncatingRemainder(dividingBy: 0.5) == 0
                        VStack(spacing: SpacingTokens.micro) {
                            Rectangle().fill(ColorTokens.Text.tertiary.opacity(0.5)).frame(width: 1, height: isWhole ? 5 : 3)
                            if isWhole {
                                Text(String(format: "%.1f s", tick)).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).fixedSize()
                            }
                        }
                        .offset(x: proxy.size.width * tick / axis)
                    }
                }
            }
            .frame(height: SpacingTokens.md)
        }
    }
}

private enum LabOCTimelineLayout {
    static let nameWidth: CGFloat = 56
    static let rowHeight: CGFloat = 18
    static let barHeight: CGFloat = 8
}
