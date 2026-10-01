import SwiftUI

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
    /// The query tab's cards: the rows under the footer soften into the system's material (round
    /// 44). Other tabs keep the light tint, as the owner asked after round 44.
    var softensUnderFooter = false
    @ViewBuilder let content: () -> Content
    @ViewBuilder let panel: () -> Panel
    @ViewBuilder let footer: () -> Footer

    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.echoMotion) private var motion

    /// Follows `panelState.isOpen`, but stays true while the panel closes, so it can fold back
    /// into the footer before it goes.
    @State private var displaysPanel = false
    /// The panel stays in the view tree once it has shown, hidden while closed, so opening it
    /// again doesn't build the grid mid-animation and closing it doesn't tear it down at the end.
    @State private var hasMountedPanel = false
    /// True while the panel grows or folds. The cards are then laid out at fixed sizes and only
    /// their clips move, so nothing lays out again on each frame.
    @State private var isAnimating = false
    /// Tells a finished animation from one that another has replaced.
    @State private var animationGeneration = 0
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
                panelOnlyCard(height: total)
            } else {
                // One continuous path for opening and closing: the content card spans from its
                // closed height (progress 0) to the split line (1), and the panel card from a
                // footer resting below the content to the space below the gap. At 0 the panel
                // card has no chrome left, so swapping its footer for the closed one is invisible.
                let closed = contentHasCards ? total - footerZone : total
                let split = splitContentHeight(total: total, gutter: gutter)
                let progress = showsPanel ? openProgress : 0
                let panelFull = max(total - split - gutter, footerZone)
                // Laid out at the size it starts or ends at; the clip does the moving.
                let contentLayoutHeight = showsPanel && !isAnimating ? split : closed
                ZStack(alignment: .top) {
                    contentCard(visibleHeight: closed + (split - closed) * progress, layoutHeight: contentLayoutHeight)
                        .frame(height: contentLayoutHeight, alignment: .top)
                    if hasMountedPanel {
                        VStack(spacing: SpacingTokens.none) {
                            Spacer(minLength: SpacingTokens.none)
                            ContentPanelCardGap(
                                height: gutter,
                                onDrag: { location in resize(toGapAt: location, total: total) },
                                onDoubleClick: toggleMaximized
                            )
                            // Rides on the panel's moving top edge.
                            .offset(y: (panelFull - footerZone) * (1 - progress))
                            .opacity(Double(progress))
                            .allowsHitTesting(showsPanel && progress > 0.99)
                            // Closed, it stays mounted but clipped to nothing, so it can't cover the content.
                            panelCard(height: panelFull, visibleHeight: showsPanel ? footerZone + (panelFull - footerZone) * progress : 0)
                        }
                        .opacity(showsPanel ? 1 : 0)
                        .allowsHitTesting(showsPanel)
                        .accessibilityHidden(!showsPanel)
                    }
                    if !showsPanel && contentHasCards {
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
            hasMountedPanel = panelState.isOpen
            openProgress = 1
        }
        .onChange(of: panelState.isOpen) { _, isOpen in
            isOpen ? growPanel() : foldPanel()
        }
    }

    /// The footer detaches first (no animation), then the panel grows up out of it. Both
    /// directions use the settle curve: no overshoot, so nothing bobs at the end.
    private func growPanel() {
        let generation = beginAnimation()
        if !displaysPanel {
            withoutAnimation {
                hasMountedPanel = true
                displaysPanel = true
                openProgress = 0
            }
        }
        Task { @MainActor in
            withAnimation(motion.settle) { openProgress = 1 }
            await finishAnimation(generation) {}
        }
    }

    private func foldPanel() {
        let generation = beginAnimation()
        withAnimation(motion.settle) { openProgress = 0 }
        // Not an animation completion: that isn't called reliably (for example when the panel
        // card holds no grid), which left a footer-high panel card behind.
        Task { @MainActor in
            await finishAnimation(generation) {
                if !panelState.isOpen { displaysPanel = false }
            }
        }
    }

    /// Fixes the layout for the animation; the cards' clips move instead.
    private func beginAnimation() -> Int {
        animationGeneration += 1
        withoutAnimation { isAnimating = true }
        return animationGeneration
    }

    /// Once the curve has finished and no newer animation has started, lets the cards take their
    /// resting sizes. The clips already match them, so nothing visibly changes.
    private func finishAnimation(_ generation: Int, then finish: () -> Void) async {
        try? await Task.sleep(for: .seconds(motion.settleDuration))
        guard generation == animationGeneration else { return }
        withoutAnimation {
            finish()
            isAnimating = false
        }
    }

    private func withoutAnimation(_ change: () -> Void) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant, change)
    }

    /// The footer floats over the bottom of whichever card holds it, with the content scrolling
    /// under a soft blur (round 9, FB1), lifted 4pt from the edge (FP1).
    private var footerZone: CGFloat { LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift }

    private var footerInContentCard: Bool { !showsPanel && !contentHasCards }

    private func contentCard(visibleHeight: CGFloat, layoutHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.cardFooterOverlayHeight, footerInContentCard ? footerZone : 0)
                .environment(\.cardHiddenBottom, max(layoutHeight - visibleHeight, 0))
                .environment(\.cardFooterRestsInCard, !contentHasCards && (!showsPanel || openProgress == 0))
                .onPreferenceChange(ContainsWorkspaceCardKey.self) { contentHasCards = $0 }
            if footerInContentCard {
                footerOverlay
            }
        }
        .modifier(RevealedWorkspaceCardModifier(
            visibleHeight: visibleHeight,
            anchor: .top,
            chromeOpacity: contentHasCards ? 0 : 1,
            clipsContent: !contentHasCards
        ))
    }

    /// The panel card, laid out at its full height and shown from the bottom up to
    /// `visibleHeight`. While it folds into the footer, its content and chrome fade, so what lands
    /// below the content is only the footer, which never moves.
    private func panelCard(height: CGFloat, visibleHeight: CGFloat) -> some View {
        let progress = isPanelOnly ? 1 : openProgress
        return ZStack(alignment: .bottom) {
            panel()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(Double(progress))
                .environment(\.cardFooterOverlayHeight, footerZone)
            footerOverlay
        }
        .frame(height: height)
        .modifier(RevealedWorkspaceCardModifier(visibleHeight: visibleHeight, anchor: .bottom, chromeOpacity: Double(progress)))
    }

    /// The panel alone (a table's data preview), with no content card.
    private func panelOnlyCard(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            panel()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .environment(\.cardFooterOverlayHeight, footerZone)
            footerOverlay
        }
        .frame(height: height)
        .workspaceCard()
    }

    /// In a query tab the rows under the footer soften into the system's material (round 44);
    /// elsewhere a light card tint towards the bottom keeps the footer readable.
    private var footerOverlay: some View {
        footer()
            .padding(.bottom, LayoutTokens.Footer.bottomLift)
            .background(alignment: .bottom) {
                if softensUnderFooter {
                    FooterMaterialBlur()
                } else {
                    ColorTokens.Workspace.card
                        .opacity(LayoutTokens.EdgeBlur.tintOpacity)
                        // An S curve, so the tint has no edge where it starts.
                        .mask(LinearGradient(stops: BackdropEdgeBlurLayerView.fadeAlphas.reversed().enumerated().map { index, alpha in
                            .init(color: .black.opacity(Double(alpha)), location: CGFloat(index) / CGFloat(BackdropEdgeBlurLayerView.fadeAlphas.count - 1))
                        }, startPoint: .top, endPoint: .bottom))
                        .frame(height: footerZone + LayoutTokens.EdgeBlur.fade)
                        .allowsHitTesting(false)
                }
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
