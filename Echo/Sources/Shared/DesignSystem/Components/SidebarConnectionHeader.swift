import SwiftUI

/// A sidebar connection header that matches SidebarRow's exact layout.
///
/// Single-line row (connection name only) with a status dot overlaid on the
/// server icon. Database type and version appear as a tooltip on hover.
/// Visually identical in height and spacing to a depth-0 SidebarRow.
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

    // MARK: - Density (matches SidebarRow exactly)

    private var densityVerticalPadding: CGFloat {
        switch density {
        case .small: return SidebarRowConstants.rowVerticalPadding // 4pt
        case .medium: return 4.5
        case .large: return 5
        }
    }

    private var densityIconFont: Font {
        switch density {
        case .small: return SidebarRowConstants.iconFont // 14pt
        case .medium: return Font.system(size: 14.5, weight: .regular)
        case .large: return Font.system(size: 15, weight: .regular)
        }
    }

    private var densityIconFrameWidth: CGFloat {
        switch density {
        case .small: return SidebarRowConstants.iconFrameWidth // 18pt
        case .medium: return 19
        case .large: return 20
        }
    }

    private var densityIconFrameHeight: CGFloat {
        switch density {
        case .small: return SidebarRowConstants.iconFrameHeight // 16pt
        case .medium: return 17
        case .large: return 18
        }
    }

    private var densityLabelFont: Font {
        switch density {
        case .small: return SidebarRowConstants.labelFont // 11pt
        case .medium: return Font.system(size: 12, weight: .regular)
        case .large: return Font.system(size: 13, weight: .regular)
        }
    }

    private var densityStatusDotSize: CGFloat {
        switch density {
        case .small: return 6
        case .medium: return 6.5
        case .large: return 7
        }
    }

    // MARK: - Icon

    private var iconColor: Color {
        isColorful ? connectionColor : ColorTokens.Sidebar.symbol
    }

    // MARK: - Highlight

    private var highlightFill: some View {
        Color.clear
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
                        .imageScale(.medium)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(iconColor)
                        .frame(width: densityIconFrameWidth, height: densityIconFrameHeight)

                    Circle()
                        .fill(statusInfo.color)
                        .frame(width: densityStatusDotSize, height: densityStatusDotSize)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.75))
                        .offset(x: 1.5, y: 1.5)
                }

                // Connection name — single line, same font as SidebarRow
                Text(connectionName)
                    .font(densityLabelFont)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)

                if isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: density == .large ? 9 : 8))
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }

                if case .error = connectionState {
                    Text("Error")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Status.error)
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
        .help(subtitle)
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
                    .font(TypographyTokens.detail.weight(.semibold))
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
