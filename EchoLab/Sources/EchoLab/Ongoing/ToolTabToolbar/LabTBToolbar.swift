import SwiftUI

/// Echo's window toolbar: the window's own groups at the left, then at the right the front tab's
/// section and the window's Search · Overview · Refresh · Bell · Inspector (round 37.5).
struct LabTBToolbar: View {
    let tab: LabTBTab
    let look: LabTBLook
    @Namespace private var glass
    /// TT21: how visible the symbol is after a switch.
    @State var flashOpacity: Double = 1
    /// TT22: whether the pointer is over the tab's buttons.
    @State var isHovering = false

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "sidebar.left") }
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "folder") }
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "clock.arrow.circlepath"); RunSpecimenGlyph(symbol: "bolt.fill") }
            Spacer(minLength: SpacingTokens.sm)
            section
                .id(look.motion == .morph ? "section" : tab.id)
                .transition(transition)
            gap
            RunSpecimenCapsule {
                ForEach(["magnifyingglass", "square.grid.2x2", "arrow.clockwise", "bell", "sidebar.right"], id: \.self) { RunSpecimenGlyph(symbol: $0) }
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: SpacingTokens.xl2 + SpacingTokens.xxs)
    }

    private var transition: AnyTransition {
        switch look.motion {
        case .melt: .opacity.combined(with: .scale(scale: 0.92))
        case .fade, .morph: .opacity
        case .slide: .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var gap: some View {
        switch look.gap {
        case .fixed, .wide: Color.clear.frame(width: look.gap.width, height: 1)
        case .hairline: Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1, height: SpacingTokens.md).padding(.horizontal, SpacingTokens.xxs2)
        }
    }

    /// The front tab's section, tied to the tab by the look.
    @ViewBuilder
    private var section: some View {
        let units = tab.units(look)
        if units.isEmpty {
            EmptyView()
        } else {
            let row = HStack(spacing: markSpacing) {
                leadingMark
                arranged(units)
                    .background(alignment: .leading) { watermark }
                    .overlay(alignment: .topLeading) { badge }
                    .overlay(alignment: .bottom) { underline }
                trailingMark
            }
            .onHover { inside in withAnimation(.easeOut(duration: 0.15)) { isHovering = inside } }
            .onAppear { flash() }
            .onChange(of: tab.id) { flash() }
            if look.tie == .caption {
                VStack(spacing: SpacingTokens.micro) {
                    row
                    symbol(font: TypographyTokens.compact, color: look.symbolColour.color(tab))
                }
            } else if look.tie.hasTray {
                row.padding(.horizontal, SpacingTokens.xxs).padding(.vertical, SpacingTokens.xxxs)
                    .background(ColorTokens.TabStrip.Background.plate, in: Capsule())
            } else {
                row
            }
        }
    }

    @ViewBuilder
    private var leadingMark: some View {
        switch look.tie {
        case .iconTray:
            Image(systemName: tab.symbol).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph).help(tab.title)
        case .name:
            Text(tab.title).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1).fixedSize()
        case .dot:
            Circle().fill(tab.tint).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
        default:
            symbolMark
        }
    }

    @ViewBuilder
    private func arranged(_ units: [LabTBUnit]) -> some View {
        switch look.groups {
        case .union:
            GlassEffectContainer(spacing: SpacingTokens.lg) {
                HStack(spacing: SpacingTokens.xxs) {
                    ForEach(Array(units.enumerated()), id: \.offset) { index, unit in unitView(unit, index: index, union: true) }
                }
            }
        case .overflow:
            HStack(spacing: SpacingTokens.xs) {
                if let first = units.first { unitView(first, index: 0) }
                if units.count > 1 {
                    capsule(index: 1) { RunSpecimenGlyph(symbol: "ellipsis").help("More buttons for this tab") }
                }
            }
        default:
            GlassEffectContainer(spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xs) {
                    ForEach(Array(units.enumerated()), id: \.offset) { index, unit in unitView(unit, index: index) }
                }
            }
        }
    }

    @ViewBuilder
    private func unitView(_ unit: LabTBUnit, index: Int, union: Bool = false) -> some View {
        switch unit {
        case .group(let groups):
            capsule(index: index, union: union) {
                if index == firstGroupIndex, look.tie == .icon {
                    Image(systemName: tab.symbol).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph)
                    hairline
                }
                ForEach(Array(groups.enumerated()), id: \.offset) { position, items in
                    if position > 0 { hairline }
                    ForEach(items, id: \.self) { LabTBItemView(item: $0, tab: tab, running: look.running) }
                }
            }
        case .runCapsule(let run):
            if look.running {
                Label { Text("0:42").monospacedDigit() } icon: { Image(systemName: "stop.fill") }
                    .labelStyle(.titleAndIcon)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.onFill)
                    .padding(.horizontal, SpacingTokens.sm)
                    .frame(height: LayoutTokens.Toolbar.glyph + SpacingTokens.xxs)
                    .glassEffect(.regular.tint(ColorTokens.Status.error), in: .capsule)
                    .help("Cancel")
            } else {
                capsule(index: index, union: union) { LabTBItemView(item: .mainGlyph(run), tab: tab, running: false) }
            }
        case .mainWord(let main):
            capsule(index: index, union: union) {
                HStack(spacing: SpacingTokens.xxs2) {
                    if look.running && main.runningTitle != nil {
                        LabMAPulsingDot()
                    } else {
                        Image(systemName: main.symbol).foregroundStyle(ColorTokens.accent)
                    }
                    Text(look.running ? (main.runningTitle ?? main.title) : main.title).foregroundStyle(ColorTokens.Text.secondary)
                }
                .font(TypographyTokens.standard.weight(.medium))
                .padding(.horizontal, SpacingTokens.xs)
                .frame(height: LayoutTokens.Toolbar.glyph)
            }
        }
    }

    private var firstGroupIndex: Int {
        tab.units(look).firstIndex { if case .group = $0 { true } else { false } } ?? -1
    }

    private var hairline: some View {
        Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1, height: SpacingTokens.md).padding(.horizontal, SpacingTokens.xxxs)
    }

    /// A toolbar capsule in the tie's material: glass, tinted glass, or the active tab's plate.
    @ViewBuilder
    private func capsule<Content: View>(index: Int, union: Bool = false, @ViewBuilder _ content: () -> Content) -> some View {
        let row = HStack(spacing: SpacingTokens.none) { content() }
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxxs)
        switch look.tie {
        case .plate:
            row.background(Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection))
        case .tint, .tintBoth:
            row.glassEffect(.regular.tint(tab.tint.opacity(look.tie == .tint ? 0.18 : 0.1)), in: .capsule)
                .glassEffectID(index, in: glass)
                .modifier(LabTBUnion(on: union, namespace: glass))
        default:
            row.glassEffect(.regular, in: .capsule)
                .glassEffectID(index, in: glass)
                .modifier(LabTBUnion(on: union, namespace: glass))
        }
    }
}

/// GR2: every capsule of the tab's section melts into one glass shape.
private struct LabTBUnion: ViewModifier {
    let on: Bool
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if on { content.glassEffectUnion(id: "tab", namespace: namespace) } else { content }
    }
}
