import SwiftUI

extension EnvironmentValues {
    /// How tall the footer floating over the bottom of a card is, so the AppKit content under it
    /// (the results grid, the editor) can scroll clear of it and blur beneath it (round 9, FB1).
    @Entry var cardFooterOverlayHeight: CGFloat = 0
}

/// A query tab's two cards (Design/02-layout.md, 05-components.md › Editor card): the editor
/// card on top and the results card below, one gutter apart on the canvas.
///
/// - The editor sits in the same place in the view tree whether results show or not, so it
///   keeps its scroll position, undo and focus (plan E1).
/// - The results card rises from the bottom while the editor card shrinks (E2).
/// - The gap between the cards resizes them, shows a grab capsule on hover, and a double-click
///   maximises the results, leaving a one-line editor card (E3).
/// - The footer lives in the results card, or in the editor card while there are no results.
struct EditorResultsCards<Editor: View, Results: View, Footer: View>: View {
    @Bindable var panelState: BottomPanelState
    /// Results only (a table's data preview): no editor card at all.
    var isResultsOnly = false
    var minEditorFraction: CGFloat = 0.25
    var maxEditorFraction: CGFloat = 0.8
    @ViewBuilder let editor: () -> Editor
    @ViewBuilder let results: () -> Results
    @ViewBuilder let footer: () -> Footer

    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.echoMotion) private var motion

    private var showsResults: Bool { panelState.isOpen || isResultsOnly }

    var body: some View {
        let gutter = projectStore.globalSettings.workspaceGutter.points

        GeometryReader { proxy in
            let total = proxy.size.height
            VStack(spacing: SpacingTokens.none) {
                if !isResultsOnly {
                    editorCard
                        .frame(height: showsResults ? editorHeight(total: total, gutter: gutter) : total)
                }
                if showsResults {
                    if !isResultsOnly {
                        EditorResultsCardGap(
                            height: gutter,
                            onDrag: { location in resize(toGapAt: location, total: total) },
                            onDoubleClick: toggleMaximized
                        )
                    }
                    resultsCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .coordinateSpace(.named(EditorResultsCardGap.coordinateSpace))
        }
        .animation(motion.standard, value: panelState.isOpen)
        .animation(motion.standard, value: panelState.isResultsMaximized)
    }

    /// The footer floats over the bottom of whichever card holds it, with the content scrolling
    /// under a soft blur (round 9, FB1), lifted 4pt from the edge (FP1).
    private var footerZone: CGFloat { LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift }

    private var editorCard: some View {
        ZStack(alignment: .bottom) {
            editor()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.cardFooterOverlayHeight, showsResults ? 0 : footerZone)
            if !showsResults {
                footerOverlay
            }
        }
        .workspaceCard()
    }

    private var resultsCard: some View {
        ZStack(alignment: .bottom) {
            results()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .environment(\.cardFooterOverlayHeight, footerZone)
            footerOverlay
        }
        .workspaceCard()
    }

    /// A light card tint towards the bottom keeps the footer readable over the blur.
    private var footerOverlay: some View {
        footer()
            .padding(.bottom, LayoutTokens.Footer.bottomLift)
            .background(alignment: .bottom) {
                ColorTokens.Workspace.card
                    .opacity(LayoutTokens.Workspace.pinnedHeaderTintOpacity)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    .frame(height: footerZone + LayoutTokens.Workspace.pinnedHeaderFade)
                    .allowsHitTesting(false)
            }
    }

    // MARK: - Sizing

    private func editorHeight(total: CGFloat, gutter: CGFloat) -> CGFloat {
        if panelState.isResultsMaximized {
            return LayoutTokens.Workspace.collapsedEditorHeight
        }
        let fraction = min(max(panelState.splitRatio, minEditorFraction), maxEditorFraction)
        return max((total - gutter) * fraction, LayoutTokens.Workspace.collapsedEditorHeight)
    }

    /// Dragging the gap: the editor card ends where the pointer is.
    private func resize(toGapAt y: CGFloat, total: CGFloat) {
        guard total > 0 else { return }
        panelState.isResultsMaximized = false
        panelState.splitRatio = min(max(y / total, minEditorFraction), maxEditorFraction)
    }

    private func toggleMaximized() {
        panelState.isResultsMaximized.toggle()
    }
}

/// The canvas gap between the editor and results cards: the resize handle. A small grab capsule
/// appears on hover; drag to resize, double-click to maximise or restore the results.
struct EditorResultsCardGap: View {
    let height: CGFloat
    /// The pointer's position in the cards' coordinate space while dragging.
    let onDrag: (CGFloat) -> Void
    let onDoubleClick: () -> Void

    @State private var isHovering = false
    @Environment(\.echoMotion) private var motion

    static let coordinateSpace = "editor-results-cards"

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                Capsule()
                    .fill(ColorTokens.Text.tertiary)
                    .frame(width: LayoutTokens.Workspace.gapHandleWidth, height: LayoutTokens.Workspace.gapHandleHeight)
                    .opacity(isHovering ? 1 : 0)
            }
            .contentShape(Rectangle().inset(by: -LayoutTokens.Workspace.gapHitSlop))
            .pointerStyle(.rowResize)
            .onHover { hovering in
                withAnimation(motion.hover) { isHovering = hovering }
            }
            .onTapGesture(count: 2, perform: onDoubleClick)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { value in onDrag(value.location.y) }
            )
            .accessibilityElement()
            .accessibilityLabel("Resize editor and results")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Maximize or Restore Results", onDoubleClick)
    }
}
