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
    }

    struct ModeIndicator: Identifiable {
        let id: String
        let label: String
        let icon: String
    }
}

/// The footer at the bottom of every tab's card (Design/05-components.md › Results card, FT1a).
/// No strip and no divider: the server and database float as a glass chip at the leading edge
/// (click it and the database switcher rises above it), the result views sit in their own glass
/// pill right beside it, and the status, row count and duration are quiet text at the trailing edge.
struct BottomPanelStatusBar: View {
    let configuration: BottomPanelStatusBarConfiguration

    @Environment(\.echoMotion) private var motion
    @State private var switcherClosedAt: Date?

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

    private static let reopenGuard: TimeInterval = 0.3

    private func setSwitcherOpen(_ isOpen: Bool) {
        if !isOpen { switcherClosedAt = Date() }
        withAnimation(motion.standard) {
            configuration.showDatabasePicker?.wrappedValue = isOpen
        }
    }

    /// The server · database chip. Clicking it opens the database switcher as a glass card
    /// floating just above the chip, which stays in place, and the card rises into view (round 10,
    /// L2 and A2). A click on the chip while it's open closes it.
    private var connectionChip: some View {
        Button {
            // A click on the chip while the card is open is also a click outside the card, which
            // has just closed it; don't reopen it straight away.
            if let closedAt = switcherClosedAt, Date().timeIntervalSince(closedAt) < Self.reopenGuard {
                return
            }
            setSwitcherOpen(!isSwitcherOpen)
        } label: {
            chipLabel
        }
        .buttonStyle(.plain)
        .glassEffect(canSwitchDatabase ? .regular.interactive() : .regular, in: .capsule)
        .disabled(!canSwitchDatabase)
        .help(canSwitchDatabase ? "Switch Database" : connectionText)
        .accessibilityLabel(connectionText)
        .overlay(alignment: .bottomLeading) {
            if isSwitcherOpen, let databases = configuration.availableDatabases {
                DatabaseSwitcherCard(
                    databases: databases,
                    currentDatabase: configuration.databaseName,
                    chipLabel: connectionText,
                    onSelect: { selected in
                        setSwitcherOpen(false)
                        configuration.onSwitchDatabase?(selected)
                    },
                    onDismiss: { setSwitcherOpen(false) },
                    showsChipLabel: false
                )
                // Glass on a shape behind the card, so the filter field isn't hosted inside glass
                // (a text field in glass sends AppKit's key-view walk into an endless loop).
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius))
                }
                .padding(.bottom, LayoutTokens.Footer.chipHeight + LayoutTokens.Footer.switcherGap)
                .transition(.offset(y: LayoutTokens.Footer.switcherRise).combined(with: .opacity))
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
