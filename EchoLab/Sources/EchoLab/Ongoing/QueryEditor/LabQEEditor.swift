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
            if scene.find { findBar }
            GeometryReader { proxy in
                let layout = layout
                ZStack(alignment: .topLeading) {
                    gutterSurface(layout, height: proxy.size.height)
                    backgroundMarks(layout, width: proxy.size.width)
                    textLines(layout)
                    foregroundMarks(layout, width: proxy.size.width)
                    errorMarks(layout, width: proxy.size.width)
                    runNote(layout, width: proxy.size.width)
                    if let hints { hintsView(hints, layout) }
                    if outlineEdge { outlineStrip(height: proxy.size.height) }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .overlay(alignment: zoomAlignment) { zoomOverlay }
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

    private var zoomAlignment: Alignment {
        style.zoomPlace == .bottomRight ? .bottomTrailing : .bottomLeading
    }

    /// The native find bar NSTextView shows above the text (usesFindBar).
    private var findBar: some View {
        HStack(spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
                Text(verbatim: "orders")
                Spacer(minLength: SpacingTokens.none)
                Text(verbatim: "2 found").foregroundStyle(ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.detail)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: SpacingTokens.xxs2))
            .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xxs2).strokeBorder(ColorTokens.Separator.primary))
            Image(systemName: "chevron.left").font(TypographyTokens.detail)
            Image(systemName: "chevron.right").font(TypographyTokens.detail)
            Text(verbatim: "Done").font(TypographyTokens.detail)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .background(.bar)
        .overlay(alignment: .bottom) { Rectangle().fill(ColorTokens.Separator.primary).frame(height: LayoutTokens.EditorGutter.edgeWidth) }
    }

    private func startFlash() {
        guard style.ranHighlight == .flash, scene.runNote != nil else { return }
        flash = 1
        withAnimation(motion.reduceMotion ? nil : .easeOut(duration: 1.2 * motion.durationScale).delay(0.15)) { flash = 0 }
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
