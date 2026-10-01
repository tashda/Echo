import Observation
import SwiftUI

/// Round 28: the query editor card, drawn from a `LabQEStyle` and a `LabQEScene`. Echo today and
/// every proposal on the editor pages are this one view, so they differ only where the style
/// differs. Every position comes from `LabQELayout` (columns × the font's advance), so marks sit
/// exactly on the characters they mark.
struct LabQEEditor: View {
    let style: LabQEStyle
    var scene = LabQEScene()
    /// Called when the zoom control changes the zoom (the page stores it in its controls).
    var onZoom: ((LabQEZoomLevel) -> Void)?
    var outlineEdge = false
    var hints: LabQEHintsPlace?

    @Environment(\.workspaceCardCornerRadius) var cornerRadius
    @Environment(\.echoMotion) var motion
    @State var isHoveringError = false
    @State var isHoveringGutter = false
    @State var isHoveringArrow = false
    @State var isHoveringEditor = false
    @State var showsBezel = false
    @State var flash: Double = 0
    @State var sweep: CGFloat = 0
    let replay = LabQEReplay.shared

    let palette = LabQEPalette.echo

    var layout: LabQELayout { LabQELayout(style: style) }
    var lines: [String] { scene.empty ? [""] : LabQESample.lines(misspelled: scene.misspelled) }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            card
            if style.zoomPlace == .footer { footer }
        }
    }

    private var card: some View {
        VStack(spacing: SpacingTokens.none) {
            if scene.find, style.findBar == .native { findBar(.native) }
            GeometryReader { proxy in
                let layout = layout
                ZStack(alignment: .topLeading) {
                    gutterSurface(layout, height: proxy.size.height)
                    backgroundMarks(layout, width: proxy.size.width)
                    textLines(layout)
                    findDimming(layout, size: proxy.size)
                    foregroundMarks(layout, width: proxy.size.width)
                    runningMark(layout)
                    errorMarks(layout, width: proxy.size.width)
                    runNote(layout, width: proxy.size.width)
                    if let hints { hintsView(hints, layout) }
                    if outlineEdge { outlineStrip(height: proxy.size.height) }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .overlay(alignment: zoomAlignment) { zoomOverlay }
                .overlay(alignment: findBarAlignment) {
                    if scene.find, style.findBar != .native { findBar(style.findBar) }
                }
                .overlay { bezel }
            }
        }
        .background(ColorTokens.Workspace.card)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .workspaceCard()
        .onHover { isHoveringEditor = $0 }
        .onChange(of: replay.runs) { _, _ in startFlash() }
        .onAppear { startFlash() }
        .onChange(of: style.zoom) { _, _ in showBezelBriefly() }
    }

    /// Echo draws the window inactive with the text view's secondary selection.
    var isActive: Bool { scene.isWindowActive }

    private var findBarAlignment: Alignment {
        switch style.findBar {
        case .floating, .corner: .topTrailing
        case .bottom: .bottomTrailing
        case .bottomCapsule: .bottom
        default: .top
        }
    }

    @ViewBuilder
    private func findBar(_ place: LabQEFindBarPlace) -> some View {
        if place.isImmersive {
            LabQEGlassFindBar(place: place, count: style.findCount, replace: style.replaceStyle, scope: style.findScope, showsReplace: scene.showsReplace)
        } else {
            LabQEFindBar(place: place, options: style.findOptions, count: style.findCount, showsReplace: scene.showsReplace)
        }
    }

    private var zoomAlignment: Alignment {
        style.zoomPlace == .bottomRight ? .bottomTrailing : .bottomLeading
    }

    /// Replays what-ran's motion (28.7): each look has its own length.
    private func startFlash() {
        guard scene.runNote != nil else { return }
        let seconds: Double
        switch style.ranHighlight {
        case .flash, .bracketPulse: seconds = 1.2
        case .outlineFade, .edgeGlow: seconds = 1.5
        case .gentleTint, .gutterLine: seconds = 2
        case .sweep:
            sweep = 0
            withAnimation(motion.reduceMotion ? nil : .easeInOut(duration: 0.9 * motion.durationScale).delay(0.1)) { sweep = 1 }
            return
        case .nothing, .outline, .tint: return
        }
        flash = 1
        withAnimation(motion.reduceMotion ? nil : .easeOut(duration: seconds * motion.durationScale).delay(0.15)) { flash = 0 }
    }

    private func showBezelBriefly() {
        guard style.zoomPlace == .keysOnly else { return }
        withAnimation(motion.hover) { showsBezel = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(motion.standard) { showsBezel = false }
        }
    }
}

/// Bumped by a page's "Run again" action, so the run's highlight replays.
@Observable @MainActor
final class LabQEReplay {
    static let shared = LabQEReplay()
    var runs = 0
}

/// Where the empty editor's starting points sit (EDT-1.3).
enum LabQEHintsPlace: String, CaseIterable {
    case today = "Y0 · 52pt in, 32pt down (today)"
    case firstLine = "Y1 · On the first line, where you type"

    var summary: String {
        self == .today ? "Their own inset (LayoutTokens.EmptyQueryHints), not lined up with the code or its first line."
            : "The prompt starts where the caret is, like a text field's placeholder; the chips sit under it."
    }
}
