#if DEBUG
import SwiftUI

/// A tool's pages as chips. The selected chip uses the bar style's active fill; chips fade and
/// drop in one after another when `isOpen` turns on.
struct LabRound14PageChips: View {
    let style: LabRound14BarStyle
    let pages: [String]
    let selected: String?
    var isOpen = true
    var compact = false
    let animation: Animation
    let onSelect: (String) -> Void

    @Namespace private var chipSpace

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ForEach(Array(pages.enumerated()), id: \.element) { index, page in
                Button { onSelect(page) } label: {
                    Text(page)
                        .font(compact ? TypographyTokens.label : TypographyTokens.detail)
                        .fontWeight(page == selected ? .semibold : .regular)
                        .foregroundStyle(chipTitle(isSelected: page == selected))
                        .padding(.horizontal, compact ? SpacingTokens.xxs2 : SpacingTokens.xs2)
                        .frame(height: compact ? LayoutTokens.DesignLabRound14.pageChipHeight - SpacingTokens.xxs : LayoutTokens.DesignLabRound14.pageChipHeight)
                        .background {
                            if page == selected {
                                LabRound14ActiveFill(style: style, cornerRadius: LayoutTokens.DesignLabRound14.pageChipCornerRadius)
                                    .matchedGeometryEffect(id: "page", in: chipSpace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isOpen ? 1 : 0)
                .offset(y: isOpen ? 0 : -SpacingTokens.xxs2)
                .animation(animation.delay(isOpen ? Double(index) * LayoutTokens.DesignLabRound14.pageStagger : 0), value: isOpen)
                .accessibilityAddTraits(page == selected ? .isSelected : [])
            }
        }
    }

    private func chipTitle(isSelected: Bool) -> Color {
        if isSelected { return style == .ink ? ColorTokens.DesignLabRound14.inkTitle : ColorTokens.Text.primary }
        return ColorTokens.Text.secondary
    }
}

/// ST1: a drawer that slides out under the tool's tab, with a notch pointing at it.
struct LabRound14Drawer: View {
    let style: LabRound14BarStyle
    let tab: LabRound14Tab?
    let selected: String?
    let isOpen: Bool
    let anchor: CGRect
    let animation: Animation
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            LabRound14Notch()
                .fill(notchFill)
                .frame(width: LayoutTokens.DesignLabRound14.notchWidth, height: LayoutTokens.DesignLabRound14.notchHeight)
                .offset(x: max(anchor.midX - LayoutTokens.DesignLabRound14.notchWidth / 2, 0))
            LabRound14PageChips(style: style, pages: tab?.pages ?? [], selected: selected, isOpen: isOpen, animation: animation, onSelect: onSelect)
                .padding(LayoutTokens.DesignLabRound14.plateInset / 2)
                .background(LabRound14Track(style: style))
                .offset(x: max(anchor.minX, 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isOpen ? LayoutTokens.DesignLabRound14.drawerHeight + LayoutTokens.DesignLabRound14.notchHeight : 0, alignment: .top)
        .clipped()
        .opacity(isOpen ? 1 : 0)
    }

    private var notchFill: Color {
        switch style {
        case .today: ColorTokens.TabStrip.Background.plate
        case .sunk: ColorTokens.DesignLabRound14.sunkWell
        case .ink: ColorTokens.DesignLabRound14.inkTrack
        }
    }
}

struct LabRound14Notch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// TT6: a full-width second bar with the pages on the left and the tool's controls on the right.
struct LabRound14SecondBar: View {
    let style: LabRound14BarStyle
    let tab: LabRound14Tab?
    let selected: String?
    let isOpen: Bool
    let animation: Animation
    let onSelect: (String) -> Void

    @State private var interval = "Every 5 s"
    @State private var isPaused = false

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            LabRound14PageChips(style: style, pages: tab?.pages ?? [], selected: selected, isOpen: isOpen, animation: animation, onSelect: onSelect)
            Spacer(minLength: SpacingTokens.xs)
            Picker("Refresh", selection: $interval) {
                ForEach(["Every 2 s", "Every 5 s", "Every 10 s", "Manually"], id: \.self) { Text($0) }
            }
            .labelsHidden()
            .fixedSize()
            .controlSize(.small)
            Button { isPaused.toggle() } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderless)
            .help(isPaused ? "Resume" : "Pause")
        }
        .padding(.horizontal, LayoutTokens.DesignLabRound14.plateInset / 2)
        .frame(height: LayoutTokens.DesignLabRound14.secondBarHeight)
        .background(LabRound14Track(style: style))
        .frame(height: isOpen ? LayoutTokens.DesignLabRound14.secondBarHeight : 0, alignment: .top)
        .clipped()
        .opacity(isOpen ? 1 : 0)
    }
}
#endif
