import SwiftUI

/// A sidebar connection header that integrates naturally with the tree.
///
/// Uses the same visual language as `SidebarRow` — identical hover, selection, and
/// context-menu fills — but with a two-line layout (name + version) and a slightly
/// bolder typographic treatment to distinguish servers from their children.
struct SidebarConnectionHeader: View {
    let connectionName: String
    let subtitle: String
    let databaseType: DatabaseType
    let connectionColor: Color
    let isExpanded: Binding<Bool>
    let isColorful: Bool
    let isSecure: Bool
    let connectionState: ConnectionState
    let onAction: () -> Void
    var trailingAccessory: TrailingAccessory = .chevron

    @Environment(\.sidebarDensity) private var density

    @State private var isHovered = false
    @State private var isContextMenuVisible = false

    enum TrailingAccessory {
        case chevron
        case spinner
        case retryButton(() -> Void)
        case none
    }

    private var statusInfo: (color: Color, label: String?) {
        switch connectionState {
        case .connected:
            return (Color.green, "Online")
        case .connecting, .testing:
            return (Color.orange, "Connecting")
        case .disconnected:
            return (Color.gray, "Disconnected")
        case .error:
            return (Color.red, "Failed")
        }
    }

    // MARK: - Density

    private var densityVerticalPadding: CGFloat { density == .large ? 5 : SpacingTokens.xs }
    private var densityIconFont: Font { density == .large ? Font.system(size: 15, weight: .regular) : .system(size: 14, weight: .medium) }
    private var densityIconFrameWidth: CGFloat { density == .large ? 20 : SidebarRowConstants.iconFrameWidth }
    private var densityIconFrameHeight: CGFloat { density == .large ? 18 : SidebarRowConstants.iconFrameHeight }
    private var densityNameFont: Font { density == .large ? Font.system(size: 13, weight: .medium) : SidebarRowConstants.labelFont.weight(.semibold) }
    private var densitySubtitleFont: Font { density == .large ? Font.system(size: 10) : TypographyTokens.compact }
    private var densityStatusDotSize: CGFloat { density == .large ? 7 : 6 }

    // MARK: - Icon

    private var iconColor: Color {
        isColorful ? connectionColor : ColorTokens.Sidebar.symbol
    }

    // MARK: - Highlight

    @ViewBuilder
    private var highlightFill: some View {
        if isContextMenuVisible {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Sidebar.contextFill)
        } else if isHovered {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Sidebar.hoverFill)
        } else {
            Color.clear
        }
    }

    // MARK: - Body

    var body: some View {
        Button(action: onAction) {
            HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
                // Disclosure chevron column — same fixed width as SidebarRow
                ZStack(alignment: .center) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .frame(width: SidebarRowConstants.chevronWidth)

                // Server icon with status dot
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: databaseType.symbolName)
                        .font(densityIconFont)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(iconColor)
                        .frame(width: densityIconFrameWidth, height: densityIconFrameHeight)

                    Circle()
                        .fill(statusInfo.color)
                        .frame(width: densityStatusDotSize, height: densityStatusDotSize)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.75))
                        .offset(x: 1.5, y: 1.5)
                }

                // Name + subtitle
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: SpacingTokens.xxs) {
                        Text(connectionName)
                            .font(densityNameFont)
                            .foregroundStyle(ColorTokens.Text.primary)
                            .lineLimit(1)

                        if isSecure {
                            Image(systemName: "lock.fill")
                                .font(.system(size: density == .large ? 9 : 8))
                                .foregroundStyle(ColorTokens.Text.quaternary)
                        }
                    }

                    HStack(spacing: SpacingTokens.xxs) {
                        Text(subtitle)
                            .font(densitySubtitleFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)

                        if case .error = connectionState {
                            Text("\u{2022}")
                                .font(densitySubtitleFont)
                                .foregroundStyle(ColorTokens.Status.error)
                            Text("Error")
                                .font(densitySubtitleFont)
                                .foregroundStyle(ColorTokens.Status.error)
                        }
                    }
                }

                Spacer(minLength: SpacingTokens.xxxs)

                trailingAccessoryView
            }
            .padding(.leading, SidebarRowConstants.rowLeadingPadding)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, densityVerticalPadding)
            .background(highlightFill)
            .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
            guard isHovered else { return }
            withAnimation(.easeInOut(duration: 0.1)) { isContextMenuVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { isContextMenuVisible = false }
        }
        .focusable(false)
    }

    // MARK: - Trailing Accessory

    @ViewBuilder
    private var trailingAccessoryView: some View {
        switch trailingAccessory {
        case .chevron:
            EmptyView()
        case .spinner:
            ProgressView()
                .controlSize(.small)
        case .retryButton(let action):
            Button {
                action()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .buttonStyle(.plain)
            .help("Retry connection")
            .accessibilityLabel("Retry connection")
        case .none:
            EmptyView()
        }
    }
}
