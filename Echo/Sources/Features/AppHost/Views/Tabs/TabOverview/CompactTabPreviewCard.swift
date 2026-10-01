import SwiftUI

struct CompactTabPreviewCard: View {
    @Bindable var tab: WorkspaceTab
    let isActive: Bool
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State internal var isHovering = false
    @State internal var isHoveringClose = false
    @Environment(AppearanceStore.self) internal var appearanceStore
    @Environment(\.colorScheme) internal var colorScheme
var body: some View {
    let container = RoundedRectangle(cornerRadius: 18, style: .continuous)
    VStack(alignment: .leading, spacing: SpacingTokens.xs2) {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text(tabTitle)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .lineLimit(1)
                if let subtitle = tabSubtitle {
                    Text(subtitle)
                        .font(TypographyTokens.label.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }

        if let snippet = snippet {
            Text(snippet)
                .font(TypographyTokens.compact.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(3)
        }

        statusBadge

        if !metrics.isEmpty {
            HStack(alignment: .center, spacing: SpacingTokens.xs) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    HStack(spacing: SpacingTokens.xxs) {
                        Image(systemName: metric.icon)
                        Text(metric.text)
                    }
                    .font(TypographyTokens.compact.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
    }
    .padding(SpacingTokens.sm2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            container
                .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6))
        )
        .overlay(
            container.stroke(compactBorderColor, lineWidth: isDropTarget ? 2.2 : (isActive ? 1.2 : 0.7))
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: isActive ? 12 : 6, y: isActive ? 10 : 5)
        .overlay(closeButton.padding(SpacingTokens.xxs2), alignment: .topTrailing)
        .onHover { hovering in
            isHovering = hovering
#if os(macOS)
            if !hovering { isHoveringClose = false }
#endif
        }
        .onTapGesture(perform: onSelect)
    }

    private var compactBorderColor: Color {
        if isDropTarget {
            return appearanceStore.accentColor
        }
        if isActive {
            return appearanceStore.accentColor.opacity(colorScheme == .dark ? 0.5 : 0.35)
        }
        return ColorTokens.Text.primary.opacity(colorScheme == .dark ? 0.18 : 0.08)
    }

    private var statusBadge: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: status.icon)
            Text(status.text)
        }
        .font(TypographyTokens.label.weight(.semibold))
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(status.color.opacity(colorScheme == .dark ? 0.25 : 0.12))
        )
        .foregroundStyle(status.color)
    }

    @ViewBuilder
    private var closeButton: some View {
#if os(macOS)
        if isHovering, !tab.isPinned {
            Button(action: onClose) {
                Image(systemName: isHoveringClose ? "xmark.circle.fill" : "xmark")
                    .font(TypographyTokens.caption2.weight(.semibold))
                    .foregroundStyle(isHoveringClose ? ColorTokens.Text.secondary : ColorTokens.Text.secondary.opacity(0.8))
                    .padding(SpacingTokens.xxs)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringClose = hovering
            }
        }
#else
        if !tab.isPinned {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(TypographyTokens.prominent.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(SpacingTokens.xxs)
            }
            .buttonStyle(.plain)
        }
#endif
    }
}
