#if DEBUG
import SwiftUI

/// Round 9, sections 3 and 5: where the footer sits (FP) and what shows behind it (FB).
enum LabFooterBacking: String, CaseIterable, Identifiable {
    case today = "Today"
    case soft = "FB1 Soft blur"
    case hard = "FB2 Hard edge"
    case glassBar = "FB4 Glass bar"
    var id: String { rawValue }
}

enum LabFooterPosition: String, CaseIterable, Identifiable {
    case today = "Today"
    case lift = "FP1 Lift 4pt"
    case float = "FP3 Floating"
    var id: String { rawValue }

    /// Extra space between the footer and the card's bottom edge.
    var lift: CGFloat {
        switch self {
        case .today: 0
        case .lift: 4
        case .float: 10
        }
    }
}

/// The results card with a real AppKit table and Echo's real footer on top. FB1 uses the same
/// blur the app would (`BackdropEdgeBlur`), so what you see here is what gets built.
struct LabFooterStage: View {
    @State private var backing: LabFooterBacking = .soft
    @State private var position: LabFooterPosition = .today
    @State private var isDrifting = true
    @State private var selectedSegment: PanelSegment = .results

    private var footerZone: CGFloat { LayoutTokens.Footer.height + position.lift }

    var body: some View {
        LabStage(title: "Footer: where it sits, and what shows behind it") {
            LabPicker(title: "Behind", selection: $backing, options: LabFooterBacking.allCases)
            LabPicker(title: "Position", selection: $position, options: LabFooterPosition.allCases)
            Toggle("Rows drift", isOn: $isDrifting)
        } content: {
            LabCard {
                ZStack(alignment: .bottom) {
                    LabAppKitGrid(
                        isDrifting: isDrifting,
                        bottomInset: backing == .today ? 0 : footerZone,
                        blurHeight: backing == .soft ? footerZone + LayoutTokens.Workspace.pinnedHeaderFade : footerZone,
                        blurRadii: backing == .soft ? LayoutTokens.Workspace.pinnedHeaderBlurRadii : backing == .hard ? [12] : []
                    )
                        .padding(.bottom, backing == .today ? footerZone : 0)
                    backingView
                    footer
                        .padding(.bottom, position.lift)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(width: 760, height: 380)
            .padding(24)
            .background(Color(nsColor: .windowBackgroundColor))
            .animation(.easeInOut(duration: 0.25), value: backing)
            .animation(.easeInOut(duration: 0.25), value: position)
        }
    }

    @ViewBuilder
    private var backingView: some View {
        switch backing {
        case .today:
            EmptyView()
        case .soft:
            // The blur itself sits inside the grid (`blurRadii`); this is the light tint over it.
            ZStack(alignment: .bottom) {
                Color(nsColor: .textBackgroundColor)
                    .opacity(LayoutTokens.Workspace.pinnedHeaderTintOpacity)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            }
            .frame(height: footerZone + LayoutTokens.Workspace.pinnedHeaderFade)
            .allowsHitTesting(false)
        case .hard:
            ZStack(alignment: .top) {
                Color(nsColor: .textBackgroundColor).opacity(0.82)
                Divider()
            }
            .frame(height: footerZone)
            .allowsHitTesting(false)
        case .glassBar:
            Capsule()
                .fill(.clear)
                .glassEffect(.regular, in: .capsule)
                .frame(height: LayoutTokens.Footer.height - 2)
                .padding(.horizontal, 7)
                .padding(.bottom, 7 + position.lift)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if backing == .glassBar {
            LabFlatFooter(selectedSegment: $selectedSegment)
                .padding(.horizontal, 7)
                .padding(.bottom, 7)
        } else {
            BottomPanelStatusBar(configuration: configuration)
        }
    }

    private var configuration: BottomPanelStatusBarConfiguration {
        var configuration = BottomPanelStatusBarConfiguration(
            serverName: "dwh",
            databaseName: "Dev_DM_Reporting",
            availableSegments: [.results, .messages, .executionPlan],
            selectedSegment: selectedSegment,
            onSelectSegment: { selectedSegment = $0 },
            onTogglePanel: {},
            isPanelOpen: true
        )
        configuration.metrics = .init(rowCountText: "96", rowCountLabel: "rows", durationText: "38 ms")
        configuration.statusBubble = .init(label: "Ready", tint: .green, isPulsing: false)
        configuration.availableDatabases = ["Dev_DM_Reporting", "Dev_DW_Reporting", "DM_Prod"]
        return configuration
    }
}

/// FB4's contents: one layer of glass (the bar), so the chip and the views are flat inside it.
private struct LabFlatFooter: View {
    @Binding var selectedSegment: PanelSegment
    @State private var isHoveringChip = false

    var body: some View {
        HStack(spacing: 6) {
            Text("dwh · Dev_DM_Reporting")
                .font(TypographyTokens.detail)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Color.primary.opacity(isHoveringChip ? 0.08 : 0), in: .capsule)
                .onHover { isHoveringChip = $0 }
            HStack(spacing: 0) {
                ForEach([PanelSegment.results, .messages, .executionPlan]) { segment in
                    Button { selectedSegment = segment } label: {
                        Image(systemName: segment.icon)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(segment == selectedSegment ? .primary : .secondary)
                            .frame(width: 28, height: 22)
                            .background {
                                if segment == selectedSegment {
                                    Capsule().fill(Color(nsColor: .textBackgroundColor)).shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                                }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Ready").foregroundStyle(.secondary)
                Text("96").monospacedDigit().foregroundStyle(.secondary)
                Text("38 ms").monospacedDigit().foregroundStyle(.secondary)
            }
            .font(TypographyTokens.detail)
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 4)
        .frame(height: LayoutTokens.Footer.height - 2)
    }
}
#endif
