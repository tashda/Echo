import SwiftUI

struct TabPreviewCard: View {
    @Bindable var tab: WorkspaceTab
    let isActive: Bool
    let isFocused: Bool
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State internal var isHovering = false
    @State internal var isHoveringClose = false
    @Environment(AppearanceStore.self) internal var appearanceStore
    @Environment(\.colorScheme) internal var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                previewBackground
                    .overlay(previewContent)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(SpacingTokens.xxs)

                closeButton
                    .padding(SpacingTokens.sm)
            }
            .frame(height: 140)

            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack(alignment: .center, spacing: SpacingTokens.xs) {
                    statusIndicator

                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text(tabTitle)
                            .font(TypographyTokens.prominent.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.primary)
                            .lineLimit(1)

                        if let subtitle = tabSubtitle {
                            Text(subtitle)
                                .font(TypographyTokens.detail.weight(.medium))
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: SpacingTokens.none)

                    if isActive {
                        activeBadge
                    } else {
                        statusBadge
                    }
                }

                footerMetrics
            }
            .padding(.horizontal, SpacingTokens.md1)
            .padding(.vertical, SpacingTokens.md)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardBorder)
        .overlay(focusRing)
        .shadow(color: cardShadow, radius: isFocused ? 20 : 12, y: isFocused ? 12 : 6)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .onHover { hovering in
            isHovering = hovering
#if os(macOS)
            if !hovering { isHoveringClose = false }
#endif
        }
        .onTapGesture(perform: onSelect)
        .accessibilityIdentifier("tab-card-\(tab.id)")
    }

    @ViewBuilder
    private var closeButton: some View {
#if os(macOS)
        if isHovering, !tab.isPinned {
            Button(action: onClose) {
                Image(systemName: isHoveringClose ? "xmark.circle.fill" : "xmark.circle.fill")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isHoveringClose ? ColorTokens.Text.primary : ColorTokens.Text.secondary, .ultraThinMaterial)
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
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .buttonStyle(.plain)
        }
#endif
    }

    private var activeBadge: some View {
        let accent = appearanceStore.accentColor
        return Text("Active")
            .font(TypographyTokens.detail.weight(.semibold))
            .padding(.horizontal, SpacingTokens.xs2)
            .padding(.vertical, SpacingTokens.xxs)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(colorScheme == .dark ? 0.4 : 0.18))
            )
            .foregroundStyle(accent)
    }

    private var statusBadge: some View {
        let status = tabStatus
        return Label {
            Text(status.text)
        } icon: {
            Image(systemName: status.icon)
        }
        .font(TypographyTokens.detail.weight(.semibold))
        .padding(.horizontal, SpacingTokens.xs2)
        .padding(.vertical, SpacingTokens.xxs2)
        .background(
            Capsule(style: .continuous)
                .fill(status.color.opacity(colorScheme == .dark ? 0.24 : 0.1))
        )
        .foregroundStyle(status.color)
    }

    private var footerMetrics: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs2) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                HStack(spacing: SpacingTokens.xxs2) {
                    Image(systemName: metric.icon)
                    Text(metric.text)
                }
                .font(TypographyTokens.detail.weight(.medium))
                .padding(.horizontal, SpacingTokens.xs2)
                .padding(.vertical, SpacingTokens.xxs2)
                .background(
                    Capsule(style: .continuous)
                        .fill(metric.color.opacity(colorScheme == .dark ? 0.22 : 0.12))
                )
                .foregroundStyle(metric.color)
            }
            Spacer(minLength: SpacingTokens.none)
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(tabStatus.color.opacity(0.9))
            .frame(width: SpacingTokens.xs2, height: SpacingTokens.xs2)
            .shadow(color: tabStatus.color.opacity(0.35), radius: 4, y: 1)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch tab.kind {
        case .query:
            if let query = tab.query {
                QueryTabPreview(query: query)
            } else {
                EmptyPreviewPlaceholder(message: "Query unavailable")
            }
        case .diagram:
            if let diagram = tab.diagram {
                DiagramTabPreview(diagram: diagram)
            } else {
                EmptyPreviewPlaceholder(message: "Diagram unavailable")
            }
        case .structure:
            if let editor = tab.structureEditor {
                StructureTabPreview(editor: editor)
            } else {
                EmptyPreviewPlaceholder(message: "Structure unavailable")
            }
        case .jobQueue:
            EmptyPreviewPlaceholder(message: "Jobs")
        case .psql:
            EmptyPreviewPlaceholder(message: "Terminal")
        case .extensionStructure:
            if let vm = tab.extensionStructure {
                ExtensionStructureTabPreview(viewModel: vm)
            } else {
                EmptyPreviewPlaceholder(message: "Extension unavailable")
            }
        case .extensionsManager:
            if let vm = tab.extensionsManager {
                ExtensionsTabPreview(viewModel: vm)
            } else {
                EmptyPreviewPlaceholder(message: "Manager unavailable")
            }
        case .activityMonitor:
            ActivityMonitorPreview(viewModel: tab.activityMonitor)
        case .queryStore:
            QueryStorePreview(viewModel: tab.queryStoreVM)
        case .extendedEvents:
            ExtendedEventsPreview()
        }
    }
}

struct QueryStorePreview: View {
    let viewModel: QueryStoreViewModel?
    var body: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "chart.bar.xaxis")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Query Store")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}

struct ExtendedEventsPreview: View {
    var body: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "waveform.path.ecg")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Extended Events")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}

struct ActivityMonitorPreview: View {
    let viewModel: ActivityMonitorViewModel?
    var body: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Activity Monitor")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
