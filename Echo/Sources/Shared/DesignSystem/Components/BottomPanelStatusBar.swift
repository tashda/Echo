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
        /// The selected cells' count, sum and average (plan R5).
        var selectionText: String? = nil
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
/// (click it and it grows into the database switcher), the result views sit in their own glass
/// pill right beside it, and the status, row count and duration are quiet text at the trailing edge.
struct BottomPanelStatusBar: View {
    let configuration: BottomPanelStatusBarConfiguration

    @Environment(\.echoMotion) private var motion
    @Namespace private var switcherNamespace

    private static let switcherGeometryID = "database-switcher"

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            connectionChip
                .zIndex(1)
            // The switcher grows over these and its glass would show them through it, so they
            // step aside while it's open.
            if !isSwitcherOpen {
                segmentPill
                modeIndicatorChips
            }
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

    private var canSwitchDatabase: Bool {
        configuration.availableDatabases != nil && configuration.onSwitchDatabase != nil
    }

    private var isSwitcherOpen: Bool {
        configuration.showDatabasePicker?.wrappedValue ?? false
    }

    private func setSwitcherOpen(_ isOpen: Bool) {
        withAnimation(motion.standard) {
            configuration.showDatabasePicker?.wrappedValue = isOpen
        }
    }

    /// The server · database chip. Clicking it grows it upward into the database switcher, whose
    /// bottom row takes the chip's place (round 9, DB1); the chip keeps its width meanwhile so
    /// nothing beside it moves.
    @ViewBuilder
    private var connectionChip: some View {
        if isSwitcherOpen, let databases = configuration.availableDatabases {
            // Invisible rather than `.hidden()`: a hidden view leaves SwiftUI's focus tree while
            // the filter field in its overlay is in it, and AppKit's key-view walk then never ends.
            chipLabel
                .opacity(0)
                .accessibilityHidden(true)
                .overlay(alignment: .bottomLeading) {
                    DatabaseSwitcherCard(
                        databases: databases,
                        currentDatabase: configuration.databaseName,
                        chipLabel: connectionText,
                        onSelect: { selected in
                            setSwitcherOpen(false)
                            configuration.onSwitchDatabase?(selected)
                        },
                        onDismiss: { setSwitcherOpen(false) }
                    )
                    // Glass on a shape behind the card, so the filter field isn't hosted inside it.
                    .background {
                        Color.clear
                            .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius))
                    }
                    .matchedGeometryEffect(id: Self.switcherGeometryID, in: switcherNamespace)
                }
        } else {
            Button {
                setSwitcherOpen(true)
            } label: {
                chipLabel
            }
            .buttonStyle(.plain)
            .glassEffect(canSwitchDatabase ? .regular.interactive() : .regular, in: .capsule)
            // Not a GlassEffectContainer morph: a text field inside a glass container sends
            // AppKit's key-view walk into an endless loop, so the chip's frame grows instead.
            .matchedGeometryEffect(id: Self.switcherGeometryID, in: switcherNamespace)
            .disabled(!canSwitchDatabase)
            .help(canSwitchDatabase ? "Switch Database" : connectionText)
            .accessibilityLabel(connectionText)
        }
    }

    private var chipLabel: some View {
        Text(connectionText)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
            .frame(height: LayoutTokens.Footer.chipHeight)
            .contentShape(Capsule())
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
                if let selection = metrics.selectionText {
                    Text(selection)
                        .font(TypographyTokens.detail.monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
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
