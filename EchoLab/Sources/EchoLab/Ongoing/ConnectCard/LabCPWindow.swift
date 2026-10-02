import SwiftUI

/// The trail with its three objects (connected pill, recents pill, connect circle) and the tree.
/// Press the circle to open the card; click outside it, press Escape or the close button to dismiss.
struct LabCPWindow: View {
    let look: LabCPLook
    @State private var isOpen = false
    @State private var circle: CGRect = .zero
    @State private var selected = "test"
    @Namespace private var glass
    @Environment(\.echoMotion) private var motion

    private let connected = ["prod", "test", "dev"]
    private let recents = ["norway", "tippr", "pgservices"]
    private var itemSize: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var railPad: CGFloat { LayoutTokens.Rail.pillPadding }
    private var cardWidth: CGFloat { SpacingTokens.xxxl * 3.9 }
    private var cardHeight: CGFloat { SpacingTokens.xxxl * 5.2 }
    private var gutter: CGFloat { itemSize + railPad * 2 + SpacingTokens.sm + SpacingTokens.xxs1 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tree.padding(.leading, gutter)
            if isOpen, look.scrim == .light { Color.black.opacity(0.1).transition(.opacity) }
            // Everything outside the card dismisses it.
            if isOpen { Color.clear.contentShape(Rectangle()).onTapGesture { toggle() } }
            GlassEffectContainer(spacing: SpacingTokens.xs) {
                ZStack(alignment: .topLeading) {
                    rail.padding(.leading, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1)
                    if isOpen { card }
                }
            }
        }
        .coordinateSpace(name: "cp")
        .onPreferenceChange(LabMVFrames.self) { circle = $0["circle"] ?? circle }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .onExitCommand { if isOpen { toggle() } }
    }

    /// Opening springs; closing settles without overshoot.
    private func toggle() { withAnimation(isOpen ? motion.settle : motion.standard) { isOpen.toggle() } }

    // MARK: Tree

    private var tree: some View {
        VStack(spacing: SpacingTokens.xs) {
            LabHCCard(server: .test, look: LabHCLook(), rowLimit: 2, interactive: false)
            LabHCCard(server: .development, look: LabHCLook(), rowLimit: 2, interactive: false)
        }
        .padding(.trailing, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Trail

    private var othersOpacity: Double {
        guard isOpen else { return 1 }
        if look.presentation == .merge { return 0 }
        switch look.others {
        case .stay: return 1
        case .dim: return 0.45
        case .fade: return 0
        }
    }

    private var rail: some View {
        VStack(spacing: SpacingTokens.xs) {
            Group {
                pill { ForEach(connected, id: \.self) { mark($0, dim: false) } }
                pill { ForEach(recents, id: \.self) { mark($0, dim: true) } }
            }
            .opacity(othersOpacity)
            .allowsHitTesting(!isOpen || look.others == .stay)
            connectButton
        }
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: LayoutTokens.Rail.itemSpacing) { content() }
            .padding(railPad)
            .glassEffect(.regular, in: .capsule)
    }

    private func mark(_ id: String, dim: Bool) -> some View {
        ZStack {
            if !dim, selected == id {
                Capsule().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection).padding(LayoutTokens.Rail.selectionInset)
            }
            LabTIMark(server: .named(id), style: .monogram, isSelected: !dim && selected == id, size: itemSize).opacity(dim ? 0.38 : 1)
        }
        .frame(width: itemSize, height: itemSize)
        .onTapGesture { if !dim { selected = id } }
    }

    private var connectButton: some View {
        Button { toggle() } label: {
            Image(systemName: isOpen && look.button == .morphs ? "xmark" : "server.rack")
                .font(.system(size: LayoutTokens.Rail.toolSymbolSize, weight: .medium))
                .foregroundStyle(ColorTokens.Text.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: itemSize, height: itemSize)
                .background {
                    if isOpen && look.button == .stays { Circle().fill(ColorTokens.Text.primary.opacity(0.1)) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(railPad)
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID(look.presentation == .grows ? "card" : "circle", in: glass)
        .opacity(isOpen && look.button == .hidden && look.presentation != .merge ? 0 : 1)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: LabMVFrames.self, value: ["circle": proxy.frame(in: .named("cp"))])
        })
        .popover(isPresented: Binding(get: { isOpen && look.presentation == .popover }, set: { if !$0, isOpen { toggle() } }), arrowEdge: .trailing) {
            cardContent.frame(width: cardWidth, height: cardHeight)
        }
    }

    // MARK: Card

    @ViewBuilder
    private var card: some View {
        switch look.presentation {
        case .grows:
            glassCard.glassEffectID("card", in: glass).offset(x: circle.maxX + SpacingTokens.xs, y: max(circle.maxY - cardHeight, SpacingTokens.xs))
        case .scales:
            glassCard.offset(x: circle.maxX + SpacingTokens.xs, y: max(circle.maxY - cardHeight, SpacingTokens.xs))
                .transition(.scale(scale: 0.5, anchor: .bottomLeading).combined(with: .opacity))
        case .merge:
            glassCard.offset(x: SpacingTokens.xxs1, y: SpacingTokens.xxs1).transition(.scale(scale: 0.4, anchor: .topLeading).combined(with: .opacity))
        case .drawer:
            glassCard.frame(maxHeight: .infinity).padding(.vertical, SpacingTokens.xxs1)
                .offset(x: gutter - SpacingTokens.xxs).transition(.move(edge: .leading).combined(with: .opacity))
        case .palette:
            glassCard.frame(maxWidth: .infinity).padding(.top, SpacingTokens.xxl)
                .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
        case .popover:
            EmptyView()
        }
    }

    private var glassCard: some View {
        cardContent
            .frame(width: cardWidth, height: look.presentation == .drawer ? nil : cardHeight)
            .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.lg, style: .continuous))
    }

    @ViewBuilder
    private var cardContent: some View {
        let list = look.listLook
        if look.content == .header {
            VStack(spacing: SpacingTokens.xxs) {
                LabCMOpenedHeader(look: list, servers: connected.map { LabTIServer.named($0) }, selected: $selected, namespace: glass, onClose: { toggle() })
                LabCMList(look: list, onConnect: { toggle() })
            }
            .padding(SpacingTokens.xxs)
        } else {
            LabCMList(look: list, onConnect: { toggle() }, onClose: look.close == .yes ? { toggle() } : nil)
            .padding(SpacingTokens.xxs)
        }
    }
}
