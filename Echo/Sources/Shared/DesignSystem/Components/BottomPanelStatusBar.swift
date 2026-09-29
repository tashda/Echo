import SwiftUI

/// Configuration data for the bottom panel status bar.
struct BottomPanelStatusBarConfiguration {
    let serverName: String
    let databaseName: String?
    let availableSegments: [PanelSegment]
    let disabledSegments: Set<PanelSegment>
    let selectedSegment: PanelSegment
    let onSelectSegment: (PanelSegment) -> Void
    let onTogglePanel: () -> Void
    let isPanelOpen: Bool

    var metrics: Metrics?
    var statusBubble: StatusBubble?
    var modeIndicators: [ModeIndicator] = []
    var statisticsPopover: AnyView?
    var showStatisticsPopover: Binding<Bool>?

    /// Database switching support — nil means no switching available.
    var availableDatabases: [String]?
    var onSwitchDatabase: ((String) -> Void)?
    var showDatabasePicker: Binding<Bool>?

    init(
        serverName: String,
        databaseName: String?,
        availableSegments: [PanelSegment],
        disabledSegments: Set<PanelSegment> = [],
        selectedSegment: PanelSegment,
        onSelectSegment: @escaping (PanelSegment) -> Void,
        onTogglePanel: @escaping () -> Void,
        isPanelOpen: Bool
    ) {
        self.serverName = serverName
        self.databaseName = databaseName
        self.availableSegments = availableSegments
        self.disabledSegments = disabledSegments
        self.selectedSegment = selectedSegment
        self.onSelectSegment = onSelectSegment
        self.onTogglePanel = onTogglePanel
        self.isPanelOpen = isPanelOpen
    }

    struct Metrics {
        let rowCountText: String
        let rowCountLabel: String
        let durationText: String?
    }

    struct StatusBubble {
        let label: String
        let tint: Color
        let isPulsing: Bool
    }

    struct ModeIndicator: Identifiable {
        let id: String
        let label: String
        let icon: String
    }
}

/// The footer at the bottom of every tab's card (Design/05-components.md › Results card, FT1a).
/// No strip and no divider: the server and database float as a glass chip at the leading edge
/// (click it to switch database), the result views sit in their own glass pill in the middle,
/// and the status, row count and duration are quiet text at the trailing edge.
struct BottomPanelStatusBar: View {
    let configuration: BottomPanelStatusBarConfiguration

    @Environment(\.echoMotion) private var motion

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            connectionChip
            modeIndicatorChips
            Spacer(minLength: SpacingTokens.sm)
                .contentShape(Rectangle())
                .onTapGesture { configuration.onTogglePanel() }
            segmentPill
            Spacer(minLength: SpacingTokens.sm)
                .contentShape(Rectangle())
                .onTapGesture { configuration.onTogglePanel() }
            metricsSection
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: LayoutTokens.Footer.height)
    }

    // MARK: - Connection

    private var connectionText: String {
        guard let databaseName = configuration.databaseName else { return configuration.serverName }
        return "\(configuration.serverName) · \(databaseName)"
    }

    private var connectionChip: some View {
        let canSwitch = configuration.availableDatabases != nil
        return Button {
            configuration.showDatabasePicker?.wrappedValue.toggle()
        } label: {
            Text(connectionText)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
                .frame(height: LayoutTokens.Footer.chipHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(canSwitch ? .regular.interactive() : .regular, in: .capsule)
        .disabled(!canSwitch)
        .help(canSwitch ? "Switch Database" : connectionText)
        .accessibilityLabel(connectionText)
        .popover(isPresented: configuration.showDatabasePicker ?? .constant(false)) {
            if let databases = configuration.availableDatabases,
               let onSwitch = configuration.onSwitchDatabase,
               let current = configuration.databaseName {
                DatabasePickerPopover(
                    databases: databases,
                    currentDatabase: current,
                    onSelect: { selected in
                        configuration.showDatabasePicker?.wrappedValue = false
                        onSwitch(selected)
                    }
                )
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var segmentPill: some View {
        if !configuration.availableSegments.isEmpty {
            HStack(spacing: SpacingTokens.none) {
                ForEach(configuration.availableSegments, id: \.self) { segment in
                    segmentButton(segment)
                }
            }
            .padding(LayoutTokens.Footer.pillPadding)
            .glassEffect(.regular, in: .capsule)
            .animation(motion.press, value: configuration.selectedSegment)
            .animation(motion.press, value: configuration.isPanelOpen)
        }
    }

    private func segmentButton(_ segment: PanelSegment) -> some View {
        let isActive = configuration.isPanelOpen && configuration.selectedSegment == segment
        let isDisabled = configuration.disabledSegments.contains(segment)
        return Button {
            configuration.onSelectSegment(segment)
        } label: {
            Image(systemName: segment.icon)
                .font(TypographyTokens.detail)
                .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.Footer.segmentWidth, height: LayoutTokens.Footer.chipHeight - LayoutTokens.Footer.pillPadding * 2)
                .background {
                    if isActive {
                        Capsule()
                            .fill(ColorTokens.Workspace.card)
                            .shadow(ShadowTokens.railSelection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.3 : 1)
        .disabled(isDisabled)
        .help(isDisabled ? segment.label : (isActive ? "Hide \(segment.label)" : "Show \(segment.label)"))
        .accessibilityLabel(segment.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private var modeIndicatorChips: some View {
        ForEach(configuration.modeIndicators) { indicator in
            HStack(spacing: SpacingTokens.xxxs) {
                Image(systemName: indicator.icon)
                Text(indicator.label)
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Status.modeIndicator)
            .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
            .frame(height: LayoutTokens.Footer.chipHeight)
            .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        HStack(spacing: SpacingTokens.xs) {
            if let bubble = configuration.statusBubble {
                HStack(spacing: SpacingTokens.xxs) {
                    PulsingStatusDot(tint: bubble.tint, isPulsing: bubble.isPulsing)
                    Text(bubble.label)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            if let metrics = configuration.metrics {
                HStack(spacing: SpacingTokens.xxxs) {
                    Text(metrics.rowCountText)
                        .font(TypographyTokens.detail.monospaced().weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text(metrics.rowCountLabel)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }

                if let duration = metrics.durationText {
                    Text(duration)
                        .font(TypographyTokens.detail.monospaced().weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if configuration.statisticsPopover != nil,
               let binding = configuration.showStatisticsPopover {
                binding.wrappedValue.toggle()
            } else {
                configuration.onTogglePanel()
            }
        }
        .popover(isPresented: configuration.showStatisticsPopover ?? .constant(false)) {
            if let popoverView = configuration.statisticsPopover {
                popoverView
            }
        }
    }
}

// MARK: - Database Picker Popover

private struct DatabasePickerPopover: View {
    let databases: [String]
    let currentDatabase: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(databases, id: \.self) { db in
                    DatabasePickerRow(
                        name: db,
                        isCurrent: db.caseInsensitiveCompare(currentDatabase) == .orderedSame,
                        onSelect: { onSelect(db) }
                    )
                }
            }
            .padding(.vertical, SpacingTokens.xxs)
        }
        .frame(width: 220)
        .frame(maxHeight: 300)
    }
}

private struct DatabasePickerRow: View {
    let name: String
    let isCurrent: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "checkmark")
                    .font(TypographyTokens.compact)
                    .frame(width: 14)
                    .foregroundStyle(ColorTokens.accent)
                    .opacity(isCurrent ? 1 : 0)

                Text(name)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs)
            .contentShape(Rectangle())
            .background(isHovered ? ColorTokens.Text.primary.opacity(0.06) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
