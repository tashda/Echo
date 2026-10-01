import SwiftUI

/// A sidebar connection header that matches SidebarRow's exact layout.
///
/// Top-level connection row for Explorer. It keeps the native outline-view
/// interaction model while giving each connected server a clear visual identity.
struct SidebarConnectionHeader: View {
    let connectionName: String
    let subtitle: String
    let databaseType: DatabaseType
    let connectionColor: Color
    let isExpanded: Binding<Bool>
    var isSelected: Bool = false
    let isColorful: Bool
    let isSecure: Bool
    let connectionState: ConnectionState
    let onAction: () -> Void
    var trailingAccessory: TrailingAccessory = .chevron
    var statusPresentation: StatusPresentation = .overlayIcon

    @Environment(\.sidebarDensity) private var density

    enum TrailingAccessory {
        case chevron
        case spinner
        case retryButton(() -> Void)
        case none
    }

    enum StatusPresentation {
        case overlayIcon
        case inlineDot
        case none
    }

    @State private var isHovering = false

    private var statusInfo: (color: Color, label: String?) {
        switch connectionState {
        case .connected:
            return (ColorTokens.Status.success, "Online")
        case .connecting, .testing:
            return (ColorTokens.Status.warning, "Connecting")
        case .disconnected:
            return (ColorTokens.Text.tertiary, "Disconnected")
        case .error:
            return (ColorTokens.Status.error, "Failed")
        }
    }

    // MARK: - Density (matches SidebarRow exactly)

    private var densityVerticalPadding: CGFloat {
        switch density {
        case .compact: return 2
        case .small: return 3
        case .medium: return 4
        case .large: return 6
        }
    }

    private var densityLabelFont: Font {
        switch density {
        case .compact: return .system(size: 11, weight: .semibold)
        case .small:   return .system(size: 12, weight: .semibold)
        case .medium:  return .system(size: 14, weight: .semibold)
        case .large:   return .system(size: 16, weight: .semibold)
        }
    }

    private var densitySubtitleFont: Font {
        switch density {
        case .compact: return TypographyTokens.compact
        case .small: return TypographyTokens.label
        case .medium: return TypographyTokens.detail
        case .large: return TypographyTokens.caption2
        }
    }

    private var densityStatusDotSize: CGFloat {
        switch density {
        case .compact: return 5.5
        case .small: return 6
        case .medium: return 6.5
        case .large: return 7
        }
    }

    private var densityIconTileSize: CGFloat {
        switch density {
        case .compact: return 16
        case .small: return 17
        case .medium: return 18
        case .large: return 20
        }
    }

    private var densityIconGlyphSize: CGFloat {
        switch density {
        case .compact: return 11
        case .small: return 12
        case .medium: return 13
        case .large: return 15
        }
    }

    private var densityRailHeight: CGFloat {
        switch density {
        case .compact: return 22
        case .small: return 24
        case .medium: return 28
        case .large: return 32
        }
    }

    private var resolvedConnectionColor: Color {
        isColorful ? connectionColor : ColorTokens.Sidebar.symbol
    }

    // MARK: - Highlight

    @ViewBuilder
    private var highlightFill: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(resolvedConnectionColor.opacity(0.12))
        } else if isHovering {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Sidebar.hoverFill)
        } else if isExpanded.wrappedValue {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Surface.rest)
        } else {
            Color.clear
        }
    }

    // MARK: - Body

    var body: some View {
        Button(action: onAction) {
            HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
                ZStack(alignment: .center) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .frame(width: SidebarRowConstants.chevronWidth)

                connectionRail

                serverIconView

                titleBlock

                Spacer(minLength: SpacingTokens.xxxs)

                statusAccessory
                trailingAccessoryView
            }
            .padding(.leading, SidebarRowConstants.rowLeadingPadding)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, densityVerticalPadding + SpacingTokens.xxxs)
            .background(highlightFill)
            .overlay(headerStroke)
            .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
            .onHover { isHovering = $0 }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .help(subtitle)
        .focusable(false)
    }

    private var connectionRail: some View {
        Capsule()
            .fill(resolvedConnectionColor.opacity(isExpanded.wrappedValue || isSelected ? 0.75 : 0.35))
            .frame(width: SpacingTokens.xxxs, height: densityRailHeight)
            .opacity(isExpanded.wrappedValue || isSelected || isHovering ? 1 : 0.55)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(connectionName)
                .font(densityLabelFont)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            HStack(spacing: SpacingTokens.xxs) {
                Text(subtitle)
                    .font(densitySubtitleFont)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)

                if isSecure {
                    Image(systemName: "lock.fill")
                        .font(TypographyTokens.compact.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.quaternary)
                        .accessibilityLabel("Secure connection")
                }
            }
        }
    }

    private var serverIconView: some View {
        DatabaseTypeIcon(
            databaseType: databaseType,
            tint: resolvedConnectionColor,
            isColorful: isColorful,
            presentation: .sidebar,
            glyphScale: 0.9
        )
        .frame(width: densityIconTileSize, height: densityIconTileSize)
        .overlay(alignment: .bottomTrailing) {
            if case .overlayIcon = statusPresentation {
                Circle()
                    .fill(statusInfo.color)
                    .frame(width: max(6, densityIconTileSize * 0.34), height: max(6, densityIconTileSize * 0.34))
                    .overlay(
                        Circle()
                            .strokeBorder(ColorTokens.Background.primary, lineWidth: 1)
                    )
                    .offset(x: 1, y: 1)
            }
        }
    }

    @ViewBuilder
    private var headerStroke: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .strokeBorder(resolvedConnectionColor.opacity(0.22), lineWidth: 0.75)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusInfo.color)
            .frame(width: densityStatusDotSize, height: densityStatusDotSize)
            .overlay(Circle().stroke(ColorTokens.Background.primary.opacity(0.7), lineWidth: 0.75))
    }

    @ViewBuilder
    private var statusAccessory: some View {
        switch connectionState {
        case .connected:
            if case .inlineDot = statusPresentation {
                statusDot
            }
        case .disconnected:
            if case .inlineDot = statusPresentation {
                statusDot
            }
        case .error:
            if case .inlineDot = statusPresentation {
                statusDot
            }
        case .connecting, .testing:
            if case .none = statusPresentation {
                EmptyView()
            } else {
                ProgressView()
                    .controlSize(.mini)
            }
        }
    }

    private func statusLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(SidebarRowConstants.trailingFont)
            .foregroundStyle(color)
            .lineLimit(1)
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
