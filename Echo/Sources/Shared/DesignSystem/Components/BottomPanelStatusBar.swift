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

/// Universal 24pt status bar at the bottom of every tab.
struct BottomPanelStatusBar: View {
    let configuration: BottomPanelStatusBarConfiguration

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                connectionLabel
                segmentToggles
                modeIndicatorChips
                Spacer(minLength: SpacingTokens.sm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        configuration.onTogglePanel()
                    }
                metricsSection
            }
            .padding(.leading, SpacingTokens.sm)
            .padding(.trailing, SpacingTokens.md1)
            .frame(height: 24)
        }
        .background(.bar)
    }

    private var connectionLabel: some View {
        HStack(spacing: 0) {
            Text(configuration.serverName)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)

            if let dbName = configuration.databaseName {
                Text(" • ")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.quaternary)

                databaseLabel(dbName)
            }
        }
    }

    @ViewBuilder
    private func databaseLabel(_ dbName: String) -> some View {
        let hasSwitcher = configuration.availableDatabases != nil
        Text(dbName)
            .font(TypographyTokens.detail)
            .foregroundStyle(hasSwitcher ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture {
                if let binding = configuration.showDatabasePicker {
                    binding.wrappedValue.toggle()
                }
            }
            .popover(isPresented: configuration.showDatabasePicker ?? .constant(false)) {
                if let databases = configuration.availableDatabases,
                   let onSwitch = configuration.onSwitchDatabase {
                    DatabasePickerPopover(
                        databases: databases,
                        currentDatabase: dbName,
                        onSelect: { selected in
                            configuration.showDatabasePicker?.wrappedValue = false
                            onSwitch(selected)
                        }
                    )
                }
            }
    }

    @ViewBuilder
    private var segmentToggles: some View {
        if !configuration.availableSegments.isEmpty {
            ForEach(Array(configuration.availableSegments.enumerated()), id: \.element) { index, segment in
                segmentButton(segment)
                    .padding(.leading, index == 0 ? SpacingTokens.xs : SpacingTokens.xxs)
            }
        }
    }

    @ViewBuilder
    private var modeIndicatorChips: some View {
        if !configuration.modeIndicators.isEmpty {
            Divider()
                .frame(height: 12)
                .padding(.leading, SpacingTokens.xs)
            ForEach(configuration.modeIndicators) { indicator in
                HStack(spacing: SpacingTokens.xxxs) {
                    Image(systemName: indicator.icon)
                    Text(indicator.label)
                }
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Status.modeIndicator)
                .padding(.leading, SpacingTokens.xs)
            }
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
                .foregroundStyle(isActive ? ColorTokens.accent : ColorTokens.Text.secondary)
        }
        .buttonStyle(.borderless)
        .opacity(isDisabled ? 0.3 : 1)
        .disabled(isDisabled)
        .help(isDisabled ? segment.label : (isActive ? "Show Results" : "Show \(segment.label)"))
        .accessibilityLabel(segment.label)
    }

    @ViewBuilder
    private var metricsSection: some View {
        HStack(spacing: SpacingTokens.sm) {
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

            if let bubble = configuration.statusBubble {
                HStack(spacing: SpacingTokens.xxs) {
                    PulsingStatusDot(tint: bubble.tint, isPulsing: bubble.isPulsing)
                    Text(bubble.label)
                        .font(TypographyTokens.detail)
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
