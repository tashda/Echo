import SwiftUI

/// The active shape for a bar style, shared by tabs and page chips so a tool's pages look like
/// its tab bar.
struct LabRound14ActiveFill: View {
    let style: LabRound14BarStyle
    var cornerRadius: CGFloat = LayoutTokens.DesignLabRound14.tabCornerRadius

    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    var body: some View {
        switch style {
        case .today:
            shape
                .fill(LinearGradient(colors: todayStops, startPoint: .top, endPoint: .bottom))
                .shadow(color: ColorTokens.DesignLabRound14.liftShadow, radius: LayoutTokens.DesignLabRound14.liftShadowRadius, y: LayoutTokens.DesignLabRound14.liftShadowY)
        case .sunk:
            shape
                .fill(ColorTokens.DesignLabRound14.sunkLift)
                .overlay(shape.strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.DesignLabRound14.liftEdgeWidth))
                .shadow(color: ColorTokens.DesignLabRound14.liftShadow, radius: LayoutTokens.DesignLabRound14.liftShadowRadius, y: LayoutTokens.DesignLabRound14.liftShadowY)
        case .ink:
            shape.fill(ColorTokens.DesignLabRound14.inkFill)
        }
    }

    private var todayStops: [Color] {
        colorScheme == .dark
            ? [ColorTokens.TabStrip.ActiveTab.Dark.top, ColorTokens.TabStrip.ActiveTab.Dark.bottom]
            : [ColorTokens.TabStrip.ActiveTab.Light.top, ColorTokens.TabStrip.ActiveTab.Light.bottom]
    }
}

/// The track behind the tabs (and behind a drawer's pages) for a bar style.
struct LabRound14Track: View {
    let style: LabRound14BarStyle
    var cornerRadius: CGFloat = LayoutTokens.DesignLabRound14.plateCornerRadius

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    var body: some View {
        switch style {
        case .today:
            shape.fill(ColorTokens.TabStrip.Background.plate)
        case .sunk:
            shape
                .fill(ColorTokens.DesignLabRound14.sunkWell.shadow(.inner(
                    color: ColorTokens.DesignLabRound14.sunkInnerShadow,
                    radius: LayoutTokens.DesignLabRound14.innerShadowRadius,
                    y: LayoutTokens.DesignLabRound14.innerShadowY
                )))
                .overlay(shape.strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.DesignLabRound14.liftEdgeWidth))
        case .ink:
            shape.fill(ColorTokens.DesignLabRound14.inkTrack)
        }
    }
}

/// One tab. `accessory` holds the pages of an unfolded tool tab (ST2) or its page menu (ST5).
struct LabRound14TabButton<Accessory: View>: View {
    let style: LabRound14BarStyle
    let tab: LabRound14Tab
    let isActive: Bool
    var title: Text? = nil
    var showsDivider = false
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void
    @ViewBuilder var accessory: () -> Accessory

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Button(action: onSelect) {
                HStack(spacing: SpacingTokens.xxs2) {
                    icon
                    (title ?? Text(tab.title)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(tab.title) · \(tab.database)")
            .accessibilityLabel("\(tab.title), \(tab.database)")
            .accessibilityValue(isActive ? "Selected" : "")

            accessory()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(TypographyTokens.compact.weight(.semibold))
                    .frame(width: SpacingTokens.md, height: SpacingTokens.md)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .help("Close \(tab.title)")
            .accessibilityLabel("Close \(tab.title)")
        }
        .font(TypographyTokens.detail.weight(isActive ? .semibold : .regular))
        .foregroundStyle(titleColor)
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.DesignLabRound14.tabHeight)
        .background {
            if isActive {
                LabRound14ActiveFill(style: style)
                    .matchedGeometryEffect(id: "active-tab", in: namespace)
            } else if isHovering {
                RoundedRectangle(cornerRadius: LayoutTokens.DesignLabRound14.tabCornerRadius, style: .continuous)
                    .fill(ColorTokens.DesignLabRound14.tabHover)
            }
        }
        .overlay(alignment: .leading) {
            if showsDivider {
                Rectangle()
                    .fill(ColorTokens.DesignLabRound14.tabDivider)
                    .frame(width: LayoutTokens.DesignLabRound14.dividerWidth, height: LayoutTokens.DesignLabRound14.dividerHeight)
                    .offset(x: -SpacingTokens.xxxs / 2 - LayoutTokens.DesignLabRound14.dividerWidth / 2)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var icon: some View {
        if tab.isRunning {
            ProgressView().controlSize(.mini)
                .frame(width: LayoutTokens.DesignLabRound14.tabIconWidth)
        } else {
            Image(systemName: tab.symbol)
                .frame(width: LayoutTokens.DesignLabRound14.tabIconWidth)
        }
    }

    private var titleColor: Color {
        if isActive { return style == .ink ? ColorTokens.DesignLabRound14.inkTitle : ColorTokens.Text.primary }
        return style == .ink ? ColorTokens.Text.primary : ColorTokens.Text.secondary
    }
}

extension LabRound14TabButton where Accessory == EmptyView {
    init(style: LabRound14BarStyle, tab: LabRound14Tab, isActive: Bool, title: Text? = nil, showsDivider: Bool = false,
         namespace: Namespace.ID, onSelect: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.init(style: style, tab: tab, isActive: isActive, title: title, showsDivider: showsDivider,
                  namespace: namespace, onSelect: onSelect, onClose: onClose) { EmptyView() }
    }
}
