import SwiftUI

/// The tab strip with a tool tab, drawn for round 49: click a tab to see how it moves.
struct LabTBarStrip: View {
    let tabs: [LabTBarTab]
    let stripWidth: CGFloat
    let requestedFit: LabTBarFit
    let motionStyle: LabTBarMotion
    let icons: LabTBarIcons
    let tabDot: LabTBarTabDot
    let firstActive: String

    @State var selectedTab: String?
    @State var pageByTab: [String: String] = [:]
    @State private var playToken = 0
    @Namespace var pageSpace
    @Environment(\.echoMotion) var motion

    var activeID: String { selectedTab.flatMap { id in tabs.contains { $0.id == id } ? id : nil } ?? firstActive }
    var planner: LabTBarPlanner { LabTBarPlanner(tabs: tabs, fit: fit, stripWidth: stripWidth, icons: icons) }
    var usesSlidingPlate: Bool { motionStyle != .today && motionStyle != .calm }
    var isToday: Bool { motionStyle == .today }
    var activeTab: LabTBarTab? { tabs.first { $0.id == activeID } }

    /// FP4 is FP3 while the front tool's pages fit the strip that way, and FP2 when they do not.
    var fit: LabTBarFit {
        guard requestedFit == .adaptive else { return requestedFit }
        guard let tab = activeTab, !tab.pages.isEmpty else { return .compact }
        let test = LabTBarPlanner(tabs: tabs, fit: .compact, stripWidth: stripWidth, icons: icons)
        return test.unfolded(tab) >= test.needs(tab) ? .compact : .row
    }

    /// The curve every width and the plate follow.
    var curve: Animation {
        let scale = motion.durationScale
        switch motionStyle {
        case .today: return motion.standard
        case .calm, .glide, .anchored, .printed, .frozen, .layer: return .smooth(duration: 0.3 * scale)
        case .staged: return .smooth(duration: 0.3 * scale).delay(0.12 * scale)
        }
    }

    /// How the pages of a tab appear and disappear.
    var pagesCurve: Animation {
        let scale = motion.durationScale
        switch motionStyle {
        case .today: return motion.press
        case .calm, .glide, .anchored, .printed, .frozen, .layer: return .easeOut(duration: 0.18 * scale)
        case .staged: return .easeOut(duration: 0.12 * scale)
        }
    }

    var showsDots: Bool {
        switch tabDot {
        case .keep: true
        case .several: Set(tabs.map(\.server)).count > 1
        case .remove: false
        }
    }

    var body: some View {
        let widths = planner.widths(active: activeID)
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                track(widths)
                Image(systemName: "plus").font(TypographyTokens.standard)
                    .frame(width: SpacingTokens.lg2 - SpacingTokens.xxxs, height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                    .glassEffect(.regular, in: Circle())
            }
            if fit == .row, let tab = activeTab, !tab.pages.isEmpty { pageRow(tab) }
            footer
        }
        .animation(curve, value: activeID)
    }

    private func track(_ widths: [CGFloat]) -> some View {
        ZStack(alignment: .leading) {
            if usesSlidingPlate, let index = tabs.firstIndex(where: { $0.id == activeID }) {
                Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection)
                    .frame(width: widths[index], height: Self.tabHeight)
                    .offset(x: widths[..<index].reduce(0, +))
            }
            HStack(spacing: SpacingTokens.none) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    tabView(tab, width: widths[index])
                }
            }
            if motionStyle == .layer {
                // MO7: the labels at their final positions, on a layer that does not animate.
                HStack(spacing: SpacingTokens.none) {
                    ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                        labelCell(tab, width: widths[index])
                    }
                }
                .allowsHitTesting(false)
                .transaction { $0.animation = nil }
            }
        }
        .padding(SpacingTokens.xxxs)
        .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
        .frame(width: stripWidth + SpacingTokens.xxxs * 2)
    }

    static let tabHeight = SpacingTokens.lg + SpacingTokens.xxxs

    private var footer: some View {
        HStack(spacing: SpacingTokens.sm) {
            Button { playToken += 1 } label: { Label("Play", systemImage: "play.fill") }
                .buttonStyle(.bordered).controlSize(.small)
            Text(fitCaption).font(TypographyTokens.detail).foregroundStyle(fitCaptionColor)
        }
        .task(id: playToken) { await play() }
    }

    func select(_ id: String) { selectedTab = id }

    /// Visits every tab in turn, as a click through would.
    private func play() async {
        guard playToken > 0 else { return }
        for id in tabs.map(\.id) + [firstActive] {
            if Task.isCancelled { return }
            selectedTab = id
            try? await Task.sleep(for: .milliseconds(1100))
        }
    }
}
