import SwiftUI

extension EnvironmentValues {
    /// How tall the footer floating over the bottom of a card is, so the content under it
    /// (the results grid, the editor, a message list) can scroll clear of it and blur beneath it
    /// (round 9, FB1).
    @Entry var cardFooterOverlayHeight: CGFloat = 0
}

/// A tab's content card with its panel card below, one gutter apart on the canvas: the query
/// tab's editor and results (Design/02-layout.md, 05-components.md › Editor card), and every tool
/// tab's content and bottom panel (TT1).
///
/// - The content sits in the same place in the view tree whether the panel shows or not, so it
///   keeps its scroll position, undo and focus (plan E1).
/// - The panel grows up out of the footer (round 10, RS2): the footer detaches from the content
///   card as a footer-high panel card, then the seam travels up to the split line while the
///   panel fades in. Closing runs it backwards.
/// - The gap between the cards resizes them, shows a grab capsule on hover, and a double-click
///   maximises the panel, leaving a one-line content card (E3).
/// - The footer lives in the panel card, or in the content card while the panel is closed. When
///   the content lays out cards of its own (panes side by side), there is no one card to hold
///   it, so the closed footer rests on the canvas below them.
struct ContentPanelCards<Content: View, Panel: View, Footer: View>: View {
    @Bindable var panelState: BottomPanelState
    /// Panel only (a table's data preview): no content card at all.
    var isPanelOnly = false
    var minContentFraction: CGFloat = 0.25
    var maxContentFraction: CGFloat = 0.8
    @ViewBuilder let content: () -> Content
    @ViewBuilder let panel: () -> Panel
    @ViewBuilder let footer: () -> Footer

    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.echoMotion) private var motion

    /// Follows `panelState.isOpen`, but stays true while the panel closes, so it can fold back
    /// into the footer before it goes.
    @State private var displaysPanel = false
    /// 0 while the panel card is only the footer, 1 once it reaches the split line.
    @State private var openProgress: CGFloat = 1
    /// True when the content brings cards of its own; its card then has no chrome.
    @State private var contentHasCards = false

    private var showsPanel: Bool { displaysPanel || isPanelOnly }

    var body: some View {
        let gutter = projectStore.globalSettings.workspaceGutter.points

        GeometryReader { proxy in
            let total = proxy.size.height
            if isPanelOnly {
                panelCard(height: total)
            } else {
                // One continuous path for opening and closing: the content card spans from its
                // closed height (progress 0) to the split line (1), and the panel card from a
                // footer resting below the content to the space below the gap. At 0 the panel
                // card has no chrome left, so swapping its footer for the closed one is invisible.
                let closed = contentHasCards ? total - footerZone : total
                let split = splitContentHeight(total: total, gutter: gutter)
                let progress = showsPanel ? openProgress : 0
                let panelHeight = footerZone + (total - split - gutter - footerZone) * progress
                ZStack(alignment: .top) {
                    contentCard
                        .frame(height: closed + (split - closed) * progress)
                    if showsPanel {
                        VStack(spacing: SpacingTokens.none) {
                            Spacer(minLength: SpacingTokens.none)
                            ContentPanelCardGap(
                                height: gutter,
                                onDrag: { location in resize(toGapAt: location, total: total) },
                                onDoubleClick: toggleMaximized
                            )
                            .opacity(Double(progress))
                            .allowsHitTesting(progress > 0.99)
                            panelCard(height: panelHeight)
                        }
                    } else if contentHasCards {
                        VStack(spacing: SpacingTokens.none) {
                            Spacer(minLength: SpacingTokens.none)
                            footer()
                                .padding(.bottom, LayoutTokens.Footer.bottomLift)
                        }
                    }
                }
                .coordinateSpace(.named(ContentPanelCardGap.coordinateSpace))
            }
        }
        .animation(motion.standard, value: panelState.isResultsMaximized)
        .onAppear {
            displaysPanel = panelState.isOpen
            openProgress = 1
        }
        .onChange(of: panelState.isOpen) { _, isOpen in
            isOpen ? growPanel() : foldPanel()
        }
    }

    /// The footer detaches first (no animation), then the panel grows up out of it.
    private func growPanel() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            displaysPanel = true
            openProgress = 0
        }
        Task { @MainActor in
            withAnimation(motion.standard) { openProgress = 1 }
        }
    }

    private func foldPanel() {
        withAnimation(motion.settle) {
            openProgress = 0
        }
        // Not an animation completion: that isn't called reliably (for example when the panel
        // card holds no grid), which left a footer-high panel card behind.
        let duration = motion.settleDuration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if !panelState.isOpen { displaysPanel = false }
        }
    }

    /// The footer floats over the bottom of whichever card holds it, with the content scrolling
    /// under a soft blur (round 9, FB1), lifted 4pt from the edge (FP1).
    private var footerZone: CGFloat { LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift }

    private var footerInContentCard: Bool { !showsPanel && !contentHasCards }

    private var contentCard: some View {
        ZStack(alignment: .bottom) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.cardFooterOverlayHeight, footerInContentCard ? footerZone : 0)
                .onPreferenceChange(ContainsWorkspaceCardKey.self) { contentHasCards = $0 }
            if footerInContentCard {
                footerOverlay
            }
        }
        .modifier(WorkspaceCardModifier(chromeOpacity: contentHasCards ? 0 : 1, clipsContent: !contentHasCards))
    }

    /// The panel card. While it folds into the footer, its fill, shadow and edge fade out so
    /// what lands below the content is only the footer.
    private func panelCard(height: CGFloat) -> some View {
        let progress = isPanelOnly ? 1 : openProgress
        return ZStack(alignment: .bottom) {
            panel()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .opacity(Double(progress))
                .environment(\.cardFooterOverlayHeight, footerZone)
            footerOverlay
        }
        .frame(height: height)
        .workspaceCard(chromeOpacity: min(Double(progress) * 3, 1))
    }

    /// A light card tint towards the bottom keeps the footer readable over the blur.
    private var footerOverlay: some View {
        footer()
            .padding(.bottom, LayoutTokens.Footer.bottomLift)
            .background(alignment: .bottom) {
                ColorTokens.Workspace.card
                    .opacity(LayoutTokens.EdgeBlur.tintOpacity)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    .frame(height: footerZone + LayoutTokens.EdgeBlur.fade)
                    .allowsHitTesting(false)
            }
    }

    // MARK: - Sizing

    private func splitContentHeight(total: CGFloat, gutter: CGFloat) -> CGFloat {
        if panelState.isResultsMaximized {
            return LayoutTokens.Workspace.collapsedEditorHeight
        }
        let fraction = min(max(panelState.splitRatio, minContentFraction), maxContentFraction)
        return max((total - gutter) * fraction, LayoutTokens.Workspace.collapsedEditorHeight)
    }

    /// Dragging the gap: the content card ends where the pointer is.
    private func resize(toGapAt y: CGFloat, total: CGFloat) {
        guard total > 0 else { return }
        panelState.isResultsMaximized = false
        panelState.splitRatio = min(max(y / total, minContentFraction), maxContentFraction)
    }

    private func toggleMaximized() {
        panelState.isResultsMaximized.toggle()
    }
}
