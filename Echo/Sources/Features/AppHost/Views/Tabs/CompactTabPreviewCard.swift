import SwiftUI

struct CompactTabPreviewCard: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State internal var isHovering = false
    @State internal var isHoveringClose = false
    @EnvironmentObject internal var appearanceStore: AppearanceStore
    @Environment(\.colorScheme) internal var colorScheme

    var body: some View {
        let container = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tabTitle)
                        .font(TypographyTokens.standard.weight(.semibold))
                        .lineLimit(1)
                    if let subtitle = tabSubtitle {
                        Text(subtitle)
                            .font(TypographyTokens.label.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            if let snippet = snippet {
                Text(snippet)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            statusBadge

            if !metrics.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                        HStack(spacing: 4) {
                            Image(systemName: metric.icon)
                            Text(metric.text)
                        }
                        .font(TypographyTokens.compact.weight(.medium))
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                        .background(
                            Capsule(style: .continuous)
                                .fill(metric.color.opacity(colorScheme == .dark ? 0.25 : 0.12))
                        )
                        .foregroundStyle(metric.color)
                    }
                    Spacer(minLength: 0)
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
        return Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.08)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
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
                    .foregroundStyle(isHoveringClose ? Color.secondary : Color.secondary.opacity(0.8))
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
                    .foregroundStyle(Color.secondary)
                    .padding(SpacingTokens.xxs)
            }
            .buttonStyle(.plain)
        }
#endif
    }
}
