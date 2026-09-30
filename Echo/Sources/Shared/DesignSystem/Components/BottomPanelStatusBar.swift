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
    /// How the status, selection, rows and time sit on the right (round 10, judged in the lab).
    var metricsStyle: FooterMetricsStyle = .pillPerEntry
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
        /// Drawn in `tint` instead of the dot, with the label in `tint` too (round 21, TL2).
        var icon: String?
        /// Shows how long since this date after the label once it passes a minute (round 21, TT2).
        var since: Date?
        /// Clicking the status opens these (round 21, TA2).
        var menu: [MenuItem] = []

        struct MenuItem: Identifiable {
            let title: String
            let systemImage: String
            var isDestructive = false
            let action: () -> Void
            var id: String { title }
        }
    }

    struct ModeIndicator: Identifiable {
        let id: String
        let label: String
        let icon: String
    }
}

/// The footer at the bottom of every tab's card (Design/05-components.md › Results card, FT1a).
/// No strip and no divider: the server and database float as a glass chip at the leading edge
/// (click it for the database switcher, in a popover), the result views sit in their own glass
/// pill right beside it, and the status, row count and duration are quiet text at the trailing edge.
struct BottomPanelStatusBar: View {
    let configuration: BottomPanelStatusBarConfiguration

    @Environment(\.echoMotion) private var motion

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            connectionChip
                .zIndex(1)
            segmentPill
            modeIndicatorChips
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

    /// The server · database chip. Clicking it opens the database switcher in a system popover
    /// above the chip: the popover brings the system's Liquid Glass, theming and dismissal
    /// (click outside, Esc), so the card only holds the filter and the list.
    private var connectionChip: some View {
        Button {
            setSwitcherOpen(true)
        } label: {
            chipLabel
        }
        .buttonStyle(.plain)
        .glassEffect(canSwitchDatabase ? .regular.interactive() : .regular, in: .capsule)
        .disabled(!canSwitchDatabase)
        .help(canSwitchDatabase ? "Switch Database" : connectionText)
        .accessibilityLabel(connectionText)
        .popover(isPresented: configuration.showDatabasePicker ?? .constant(false), arrowEdge: .top) {
            if let databases = configuration.availableDatabases {
                DatabaseSwitcherCard(
                    databases: databases,
                    currentDatabase: configuration.databaseName,
                    chipLabel: connectionText,
                    onSelect: { selected in
                        setSwitcherOpen(false)
                        configuration.onSwitchDatabase?(selected)
                    },
                    onDismiss: { setSwitcherOpen(false) },
                    showsChipLabel: false,
                    handlesDismissal: false
                )
            }
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
}
